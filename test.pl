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
            $c->render(template => 'index', results => \@results_slice, messages => [{ type => 'bg-warning', autohide => '0', title => 'Warning', content => "Превышено количество результатов = ".($max_elements+1) }]);
        } else {
            $c->render(template => 'index', results => \@results, messages => [{ type => 'bg-info', autohide => '1', title => 'Info', content => "Исполнено" }]);
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

    <link href="https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css" rel="stylesheet"/>

    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.3.1/jquery.min.js"></script>
    <script src="https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/js/bootstrap.min.js"></script>
    
    <style>
        * { font-size: 12px; }
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

    <% if (stash('messages')) { %>
        <% foreach my $message (@{stash('messages')}) { %>
            <div class="toast" role="alert" aria-live="assertive" aria-atomic="true" data-delay="6000" <% if (!$message->{autohide}) { %>data-autohide="false"<% } %>>
                <div class="toast-header <%= $message->{type} %> text-white">
                    <strong class="me-auto"><%= $message->{title} %></strong>
                    <small>Только что</small>
                    <button type="button" class="btn-close" data-bs-dismiss="toast" aria-label="Close"></button>
                </div>
                <div class="toast-body">
                    <%= $message->{content} %>
                </div>
            </div>
        <% } %>
    <% } %>

    <script>
        $('.toast').toast('show');
    </script>
</body>
</html>
