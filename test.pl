#!/usr/bin/perl -w
use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin/libs";
use Lib1;
use utf8;
use Mojolicious::Lite;
$|=1; # запрещаем буферизацию вывода

## Инициализация
# передача вводных параметров по вьюшке
my %hh = Lib1::html_config();
my $max_elements = $hh{'max'};
my $debug = $hh{'debug'};

# init DB
my $dbh=Lib1::connect_to_database();
# обеспечиваем структуру таблиц
Lib1::check_and_prepare_sql_structure();
# парсер - разовый запуск при отсутствии ротации лога - первичный парсинг (регулируется флагом в секции [flag] конфига)
Lib1::log_parser();

# установка настроек для поддержки UTF-8
plugin 'Charset' => {charset => 'UTF-8'};

## Вьюшка
# вывод основного содержимого на экран + передача сообщений тостами
get '/' => sub {
    my $c = shift;

    # вводные из формы
    my $search_text = $c->param('search_text');

    if ($search_text) { # введены данные для поиска
        # создаем временную таблицу 'lego' 
        my $tmp_table = "
            CREATE TEMPORARY TABLE `lego` (
                `created` timestamp NOT NULL,
                `int_id` char(16) NOT NULL,
                `str` text NOT NULL,
                KEY `created` (`created`),
                KEY `int_id` (`int_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;        
        ";
        my $sth = $dbh->prepare($tmp_table);
        $sth->execute();
                
        # подготовка выражения для вставки во временную таблицу 'lego'
        my $insert_sth = $dbh->prepare("INSERT INTO `lego` (`created`,`int_id`,`str`) VALUES (?,?,?)");

        # заполняем временную таблицу по условиям задачи - из двух таблиц (выбран вариант не через массив или хэш)
        $sth = $dbh->prepare("SELECT `created`,`int_id`,`str` FROM `message` WHERE `str` LIKE ?");
        $sth->execute("%$search_text%");
        while (my $row = $sth->fetchrow_hashref) {
            # получаем данные из SELECT
            my $created = $row->{created};
            my $int_id = $row->{int_id};
            my $str = $row->{str};
            # вставляем данные во временную таблицу 'lego'
            $insert_sth->execute($created, $int_id, $str);
        }
        $sth = $dbh->prepare("SELECT `created`,`int_id`,`str` FROM `log` WHERE `address` LIKE ?");
        $sth->execute("%$search_text%");
        while (my $row = $sth->fetchrow_hashref) {
            # получаем данные из SELECT
            my $created = $row->{created};
            my $int_id = $row->{int_id};
            my $str = $row->{str};
            # вставляем данные во временную таблицу 'lego'
            $insert_sth->execute($created, $int_id, $str);
        }

        # получение данных для вьюшки
        if ($debug) {
            $sth = $dbh->prepare("SELECT `created`,`int_id`,`str` FROM `lego` ORDER BY `int_id` DESC, `created` DESC LIMIT ".$max_elements);
        } else {
            $sth = $dbh->prepare("SELECT `str` FROM `lego` ORDER BY `int_id` DESC, `created` DESC LIMIT ".$max_elements);
        }
        $sth->execute();
        my @results;
        while (my $row = $sth->fetchrow_hashref) {
            # выделение искомого - TODO: доработка требуется
            $row =~ s/($search_text)/<span class="highlight"><%= content $1 %><\/span>/gi;
            # занесение в стек для вывода
            push @results, $row;
        }

        # проверка условия по максимальному количеству
        my $lego_count = $dbh->selectrow_array("SELECT count(`int_id`) FROM `lego`");

        my @toast_params;
        if ($lego_count>$max_elements) { # превышение указанного количества строк - во вводных данных (секция [html] конфига)
            @toast_params = [{
                title    => 'Предупреждение',
                text     => "Превышено количество полученных строк. Выведено ".$max_elements." строк из ".$lego_count.".",
                type     => 'bg-warning',
                autohide => '0'
            }];
            $c->render(debug => $debug, template => 'index', results => \@results, , messages => @toast_params);
        } else { # без превышения указанного количества строк
            @toast_params = [{
                title    => 'Информация',
                text     => "Исполнено. ".$lego_count." строк.",
                type     => 'bg-info',
                autohide => '1'
            }];
            $c->render(debug => $debug, template => 'index', results => \@results, messages => @toast_params);
        }
        # тосты не стекируются - при необходимости требуется доработка

        # убираем временную таблицу
        $sth = $dbh->prepare("DROP TABLE `lego`");
        $sth->execute();

    } else { # отображение чистой формы запроса
        $c->render(template => 'index');
    }

};

## запуск mojo
app->start;

__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html>
<head>
    <title>Вывод</title>
    <meta charset="utf-8">
    <link rel="icon" type="image/png" href="/img/favicon.ico">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        * { 
            font-size: 12px; 
        }
        .highlight {
            background-color: yellow;
        }
        .toast-top-right {
            position: fixed;
            top: 80px;
            right: 20px;
            width: 300px;
            z-index: 9999;
        }
    </style>
</head>
<body>
    <div class="container mt-4 fs-6">
        <div class="row">
            <div class="col">
                <form method="GET" action="/">
                    <div class="input-group mb-3">
                        <input type="text" class="form-control" placeholder="Введите текст" name="search_text">
                        <button class="btn btn-primary" type="submit">Поиск</button>
                    </div>
                </form>
            </div>
        </div>
        <% if (stash('results')) { %>
            <div class="row">
                <div class="col">
                    <table class="table">
                        <% if (stash('debug')) { %>
                            <thead>
                                <tr>
                                    <th>created</th>
                                    <th>int_id</th>
                                    <th>str</th>
                                </tr>
                            </thead>
                        <% } %>
                        <tbody>
                            <% foreach my $row (@{stash('results')}) { %>
                                <tr>
                                    <% if (stash('debug')) { %>
                                        <td><%= $row->{created} %></td>
                                        <td><%= $row->{int_id} %></td>
                                    <% } %>
                                    <td><%= $row->{str} %></td>
                                </tr>
                            <% } %>
                        </tbody>
                    </table>
                </div>
            </div>
        <% } %>
    </div>

    <div class="container">
        <% if (stash('messages')) { %>
            <% foreach my $message (@{stash('messages')}) { %>
                <div class="toast fade toast-fixed" role="alert" aria-live="assertive" aria-atomic="true" data-delay="3000" <% if (!$message->{autohide}) { %>data-autohide="false"<% } %>>
                    <div class="toast-header <%= $message->{type} %>">
                        <strong class="me-auto"><%= $message->{title} %></strong>
                        <button type="button" class="btn-close" data-bs-dismiss="toast" aria-label="Закрыть"></button>
                    </div>
                    <div class="toast-body">
                        <%= $message->{text} %>
                    </div>
                </div>
            <% } %>
        <% } %>
        <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function() {
            // инициализация тостов
            var toasts = document.querySelectorAll('.toast');
            var toastElements = Array.prototype.slice.call(toasts);
            var toastOptions = {
                autohide: true,
                delay: 3000
            };
            // автоскрытие под контроль
            var toastInstances = toastElements.map(function(toastElement) {
                var autohide = toastElement.getAttribute('data-autohide');
                if (autohide === 'false') {
                    toastOptions.autohide = false;
                }
                return new bootstrap.Toast(toastElement, toastOptions);
            });
            // требуемая ручная активация показа тостов
            toastInstances.forEach(function(toastInstance) {
                toastInstance._element.classList.add('toast-top-right');
                toastInstance.show();
            });
        });
    </script>
    
</body>
</html>
