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


## Вьюшка
## вывод основного содержимого на экран
get '/' => sub {
    my $c = shift;
    my $search_text = $c->param('search_text');

    my $sth;
    if ($search_text) {
        $sth = $dbh->prepare("SELECT * FROM `message` WHERE `str` LIKE ?");
        $sth->execute("%$search_text%");
    }

    my @results;
    while (my $row = $sth->fetchrow_hashref) {
        push @results, $row;
    }
    $c->stash(results => \@results);

    $c->render('index');
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
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.1/dist/css/bootstrap.min.css">
</head>
<body>
    <div class="container mt-4">
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

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.0.1/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
