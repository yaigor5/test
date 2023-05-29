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
## Парсер - разовый запуск при отсутствии ротации лога
Lib1::log_parser();


## Вьюшка
## вывод основного содержимого на экран
get '/' => sub {
    my $c = shift;
    my $sth = $dbh->prepare("SELECT * FROM `message`");
    $sth->execute();
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
    <!-- <link rel="stylesheet" type="text/css" href="/css/style.css"> -->
</head>
<body>
    <% if (stash('results')) { %>
        <table style='border: 1;'>
            <thead>
                <tr>
                    <th>created</th><th>int_id</th><th>str</th>
                </tr>
            </thead>
            <tbody>
                <% foreach my $row (@{stash('results')}) { %>
                    <tr>
                        <td><%= $row->{created} %></td><td><%= $row->{int_id} %></td><td><%= $row->{str} %></td>
                    </tr>
                <% } %>
            </tbody>
        </table>
    <% } %>
</body>
</html>
