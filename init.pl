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
    CPAN::install(Term::ANSIColor);
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
#color_print('warning', 'warning message');
#color_print('error', 'error message');
#color_print('info', 'information message');
#color_print('debug', 'debug message');
# проверим установку MySql


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
