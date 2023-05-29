#!/usr/bin/perl -w
use strict;
use warnings;
use Lib 'lib'; # Добавляем путь к каталогу "lib"
#BEGIN { unshift(@INC, '/var/www/cgi-bin/lib'); }
#use Lib qw(connect_to_database);
use Lib;
$|=1; ## запрещаем буферизацию вывода
use utf8;
use Mojolicious::Lite;
# db init
my $dbh=Lib::connect_to_database();


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

app->start;


__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html>
<head>
    <title>Привет, мир!</title>
    <meta charset="utf-8">
    <!-- <link rel="stylesheet" type="text/css" href="/css/style.css"> -->
</head>
<body>
    <% if (stash('results')) { %>
        <table>
            <thead>
                <tr>
                    <th>id</th><th>str</th>
                </tr>
            </thead>
            <tbody>
                <% foreach my $row (@{stash('results')}) { %>
                    <tr>
                        <td><%= $row->{id} %></td><td><%= $row->{str} %></td>
                    </tr>
                <% } %>
            </tbody>
        </table>
    <% } %>
</body>
</html>
