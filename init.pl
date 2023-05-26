#!/usr/bin/perl -w
use strict;
use warnings;
# проверим наличие CPAN
eval "use CPAN";
if ($@) {
    print "CPAN не установлен. Установка CPAN...\n";
    install_cpan();
} else { print "CPAN уже установлен.\n"; }
# проверим curl
unless (check_curl_installed()) {
    print "curl не установлен. Установка curl...\n";
    install_curl();
} else {  print "curl уже установлен.\n"; }
# включим цветность
eval "use Term::ANSIColor";
if ($@) {
    print "Модуль Term::ANSIColor не установлен. Установка...\n";
    CPAN::install('Term::ANSIColor');
} else { print "Term::ANSIColor уже установлен.\n"; }
sub color_print {
    my %args = (@_);
    my $type = $args{type};
    my $message = $args{message};
    my $color;
    if ($type eq 'info') { $color = 'green'; } 
    elsif ($type eq 'warning') { $color = 'yellow'; } 
    elsif ($type eq 'error') { $color = 'red'; } 
    elsif ($type eq 'debug') { $color = 'bright_black'; } 
    else { $color = 'reset'; }
    print color($color).$message.color('reset')."\n";
}
#color_print('type'=>'warning', 'message'=>'warning message');
#color_print('type'=>'error', 'message'=>'error message');
#color_print('type'=>'info', 'message'=>'information message');
#color_print('type'=>'debug', 'message'=>'debug message');
# список требуемых модулей
my @required_modules = qw(DBD::mysql Config::IniFiles Mojolicious::Lite);
eval { # проверка наличия и установка
    foreach my $module (@required_modules) {
        eval "use $module";
        if ($@) {
            color_print('type'=>'warning', 'message'=>"Модуль $module не установлен. Установка...");
            CPAN::install($module);
        }
    }
}
# проверим установку MySql
use Config::IniFiles;
use DBI;
my $config = Config::IniFiles->new(-file => 'config.ini') or die "Не удалось открыть файл config.ini: $!";
my $dsn = "DBI:mysql:database=" . $config->val('database', 'dbname') . ";host=" . $config->val('database', 'host');
my $username = $config->val('database', 'username');
my $password = $config->val('database', 'password');
my $dbh = DBI->connect($dsn, $username, $password, { mysql_enable_utf8 => 1 }) or die "Не удалось подключиться к базе данных: $DBI::errstr";



# init процедуры 
sub install_cpan { # CPAN
    my $command = get_package_manager() . " install -y perl-CPAN";
    system($command);
    # успешность установки
    if ($? == 0) {
        print "CPAN успешно установлен.\n";
    } else {
        die "Не удалось установить CPAN: $!\n";
    }
}
sub check_curl_installed { # curl
    my $output = `curl --version 2>&1`;
    return ($output =~ /curl (\d+)/);
}
sub install_curl { # curl
    my $command = get_package_manager() . " install -y curl";
    system($command);
    if ($? == 0) {
        print "curl успешно установлен.\n";
    } else {
        die "Не удалось установить curl: $!\n";
    }
}
sub get_os_type { # тип OS
    my $os = `uname`;
    if ($os =~ /Linux/i) { return "linux"; } 
    elsif ($os =~ /Darwin/i) { return "mac"; } 
    else { die "Unknown OS: $os\n"; }
}
sub get_package_manager { # тип установщика пакетов
    my $os_type = get_os_type();
    if ($os_type eq "linux") { return "sudo apt-get"; } 
    elsif ($os_type eq "mac") { return "brew"; } 
    else { die "Не удалось определить менеджер пакетов для операционной системы (Please install CPAN manually): $os_type\n"; }
}
