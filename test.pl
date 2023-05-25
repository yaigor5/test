#!/usr/bin/perl -w
##################################
### Written by IGOR YAROVOY   ####
##################################
BEGIN { unshift(@INC, '/var/www/cgi-bin/lib'); }
use 5.10.1;
use DBI;
use CGI;
use CGI::Carp qw(fatalsToBrowser); # Если будет какая-нибудь ошибка, то выведет в browser
use utf8;
use Time::localtime; 
use Data::Dumper;
use Config::Tiny;
$|=1; ## запрещаем буферизацию вывода. 
###INIT

our $VERSION = '2023-05-26';

####### script name
my $actionscriptname = $0;
$actionscriptname =~ s/.*\/www(.*)/$1/g; ## /www/cgi-bin/...
$actionscriptname =~ /([^\/]+\..*)/g;
my $scriptname = $1;

print "Content-type: text/html\n\n";

print $scriptname."<br>\n";
