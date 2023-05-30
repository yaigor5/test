#!/usr/bin/perl -w
use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin/libs";
use Lib1;
use utf8;
use Mojolicious::Lite;
$|=1; ## запрещаем буферизацию вывода

## Инициализация
## init DB
my $dbh=Lib1::connect_to_database();
## обеспечиваем структуру таблиц
Lib1::check_and_prepare_sql_structure();
## Парсер - разовый запуск при отсутствии ротации лога - TODO: вывод сообщений во вьюшку в виде тостов
Lib1::log_parser();

# Установка настроек для поддержки UTF-8
plugin 'Charset' => {charset => 'UTF-8'};

## Вьюшка
## вывод основного содержимого на экран
get '/' => sub {
    my $c = shift;

    my $search_text = $c->param('search_text');

    if ($search_text) {
        my $sth = $dbh->prepare("SELECT * FROM `message` WHERE `str` LIKE ?");
        $sth->execute("%$search_text%");

        my @results;
        while (my $row = $sth->fetchrow_hashref) {
            push @results, $row;
        }

        # TODO: переделать на анализ count()
        ## 100 !
        my $max_elements = 2;
        $max_elements--; # 0..max
        if (@results >= $max_elements) {
            my @results_slice = @results[0..$max_elements];
            $c->render(template => 'index', results => \@results_slice, messages => [{ type => 'bg-warning', title => 'Warning', content => "Превышено количество результатов = $max_elements" }]);
        } else {
            $c->render(template => 'index', results => \@results);
        }
    } else {
        $c->render(template => 'index');
    }

    # debug
    # Просмотр сгенерированного содержимого
    my $rendered_content = $c->rendered;
    # Вывод сгенерированного содержимого в консоль
    $c->app->log->debug($rendered_content);

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
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-EVSTQN3/azprG1Anm3QDgpJLIm9Nao0Yz1ztcQTwFspd3yD65VohhpuuCOmLASjC" crossorigin="anonymous">
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/js/bootstrap.bundle.min.js" integrity="sha384-MrcW6ZMFYlzcLA8Nl+NtUVF0sA7MsXsP1UyJoMp4YLEuNSfAP+JcXn/tWtIaxVXM" crossorigin="anonymous"></script>

    <script src="https://cdn.jsdelivr.net/npm/@popperjs/core@2.9.2/dist/umd/popper.min.js" integrity="sha384-IQsoLXl5PILFhosVNubq5LC7Qb9DXgDA9i+tQ8Zj3iwWAwPtgFTxbJ8NT4GN1R8p" crossorigin="anonymous"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/js/bootstrap.min.js" integrity="sha384-cVKIPhGWiC2Al4u+LWgxfKTRIcfu0JTxR+EQDz/bgldoEyl4H0zUF0QKbrJ0EcQF" crossorigin="anonymous"></script>
    <style>
        .toast {
            position: absolute;
            top: 20px;
            right: 20px;
            width: 300px;
            z-index: 9999;
        }
        * {
            font-size: 12px;
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
                        <thead>
                            <tr>
                                <th>created</th>
                                <th>int_id</th>
                                <th>str</th>
                            </tr>
                        </thead>
                        <tbody>
                            <% foreach my $row (@{stash('results')}) { %>
                                <tr>
                                    <td><%= $row->{created} %></td>
                                    <td><%= $row->{int_id} %></td>
                                    <td><%= $row->{str} %></td>
                                </tr>
                            <% } %>
                        </tbody>
                    </table>
                </div>
            </div>
        <% } %>
    </div>

    <div class="toast-container">
        <!--<% if (stash('messages')) { %>-->
            <!--<% foreach my $message (@{stash('messages')}) { %>-->
                <div class="position-fixed bottom-0 end-0 p-3" style="z-index: 11">
                    <div class="toast" role="alert" aria-live="assertive" aria-atomic="true">
                        <div class="toast-header <%= $message->{type} %> text-white">
                            <strong class="me-auto"><%= $message->{title} %></strong>
                            <button type="button" class="btn-close" data-bs-dismiss="toast" aria-label="Close"></button>
                        </div>
                        <div class="toast-body">
                            test
                            <%= $message->{content} %>
                        </div>
                    </div>
                </div>
            <!--<% } %>-->
        <!--<% } %>-->
    </div>


    <script>
        document.addEventListener('DOMContentLoaded', function() {
            var toasts = document.querySelectorAll('.toast');
            var toastList = new bootstrap.Toast(toasts, { autohide: true, delay: 60000 });
            toastList.forEach(function(toast) {
                toastList.show();
            });
        });
    </script>
</body>
</html>
