#!/usr/bin/perl -w
use strict;
use warnings;
use lib 'lib'; # Добавляем путь к каталогу "lib"
use libs;
#
#
use DBI;
use CGI;
use CGI::Carp qw(fatalsToBrowser); # Если будет какая-нибудь ошибка, то выведет в browser
use utf8;
#use Data::Dumper;
use Config::Tiny;



$|=1; ## запрещаем буферизацию вывода. 

###INIT
our $VERSION = '2023-05-26';


print "Content-type: text/html\n\n";

print "Модуль libs, версия: $libs::VERSION<br>\n";
print "Дата создания модуля: $libs::CREATED_DATE<br>\n";

