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
            $c->render(template => 'index', results => \@results_slice, messages => [{ type => 'bg-warning', title => 'Warning', content => "Превышено количество результатов = ".($max_elements+1) }]);
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

    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha3/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-KK94CHFLLe+nY2dmCWGMq91rCGa5gtU4mk92HdvYe+M/SXH301p5ILy+dN9+nJOZ" crossorigin="anonymous">

    <script src=" https://cdn.jsdelivr.net/npm/jquery@3.7.0/dist/jquery.min.js "></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha3/dist/js/bootstrap.bundle.min.js" integrity="sha384-ENjdO4Dr2bkBIFxQpeoTz1HIcje39Wm4jDKdf19U8gI4ddQ3GYNS7NTKfAdVQSZe" crossorigin="anonymous"></script>
    
    <style>
        body { font-size: 12px; }
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

    <div aria-live="polite" aria-atomic="true" class="position-relative">
        <!-- Position it: -->
        <!-- - `.toast-container` for spacing between toasts -->
        <!-- - `.position-absolute`, `top-0` & `end-0` to position the toasts in the upper right corner -->
        <!-- - `.p-3` to prevent the toasts from sticking to the edge of the container  -->
        <div class="toast-container position-absolute top-0 end-0 p-3">
            <!-- Then put toasts within -->

            <% if (stash('messages')) { %>
                <% foreach my $message (@{stash('messages')}) { %>
                    <div class="position-fixed bottom-0 end-0 p-3" style="z-index: 11">
                        <div class="toast" role="alert" aria-live="assertive" aria-atomic="true">
                            <div class="toast-header <%= $message->{type} %> text-white">
                                <strong class="me-auto"><%= $message->{title} %></strong>
                                <button type="button" class="btn-close" data-bs-dismiss="toast" aria-label="Close"></button>
                            </div>
                            <div class="toast-body">
                                <%= $message->{content} %>
                            </div>
                        </div>
                    </div>
                <% } %>
            <% } %>
        </div>
    </div>

    <script>
        $('.toast').toast('show');
        document.getElementById("toastbtn").onclick = function() {
            var toastElList = [].slice.call(document.querySelectorAll('.toast'))
            var toastList = toastElList.map(function(toastEl) {
            // Creates an array of toasts (it only initializes them)
            return new bootstrap.Toast(toastEl) // No need for options; use the default options
        });
        toastList.forEach(toast => toast.show()); // This show them
        console.log(toastList); // Testing to see if it works
        };        
    </script>
</body>
</html>
