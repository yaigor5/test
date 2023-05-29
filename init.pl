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
# включим цветность ------------------------------------
eval "use Term::ANSIColor";
if ($@) {
    print "Модуль Term::ANSIColor не установлен. Установка...\n";
    CPAN::install('Term::ANSIColor');
} else { print "Term::ANSIColor уже установлен.\n"; }
#eval {
    # проверка доступности MySQL сервера
    eval "use Config::IniFiles";
    if ($@) {
        color_print('type'=>'warning', 'message'=>"Модуль Config::IniFiles не установлен. Установка...");
        CPAN::install('Config::IniFiles');
    }
    eval "use DBI";
    if ($@) {
        color_print('type'=>'warning', 'message'=>"Модуль DBI не установлен. Установка...");
        CPAN::install('DBI');
    }
    eval "use DBD::mysql";
    if ($@) {
        color_print('type'=>'warning', 'message'=>"Модуль DBD::mysql не установлен. Установка...");
        CPAN::install("DBD::mysql");
    }
    # дополнительно проверка и установка зависимостей из cpanfile
    eval "use App::cpanminus";
    if ($@) {
        color_print('type'=>'warning', 'message'=>"Модуль App::cpanminus не установлен. Установка...");
        CPAN::install("App::cpanminus");
    }
    eval "use App::cpanminus::script";
    if ($@) {
        color_print('type'=>'warning', 'message'=>"Модуль App::cpanminus::script не установлен. Установка...");
        CPAN::install("App::cpanminus::script");
    }
    # установка
    install_dependencies();
    if ($? != 0) { 
        color_print('type'=>'warning', 'message'=>"Ошибка установки зависимостей."); 
        exit;  
    } else { color_print('type'=>'info', 'message'=>"Установка зависимостей Perl завершена."); }
    # считываем конфиг для подключения к БД
    my $config = Config::IniFiles->new(-file => 'config.ini') or die "Не удалось открыть файл config.ini: $!";
    my $mysql_host = $config->val('database', 'host');
    my $mysql_port = $config->val('database', 'port');
    my $mysql_user = $config->val('database', 'username');
    my $mysql_pass = $config->val('database', 'password');
    my $mysql_db = $config->val('database', 'dbname');
    my $dbh;
    # пробное подключение к MySQL
    eval {
        $dbh = DBI->connect("DBI:mysql:host=$mysql_host;port=$mysql_port", $mysql_user, $mysql_pass);
    };
    # при недоступности - установка и настройка
    if ($@ || !$dbh) {
        color_print('type'=>'warning', 'message'=>"Не удалось подключиться к MySQL серверу. Установка и настройка...");
        # установка MySQL
        install_mysql();
        # настройка MySQL
        #system("sudo mysql -e 'ALTER USER \"root\"@\"localhost\" IDENTIFIED WITH mysql_native_password BY \"\"; FLUSH PRIVILEGES;'");
        my $dbh_root = DBI->connect("DBI:mysql:host=$mysql_host;port=$mysql_port", 'root', '');
        die "Не удалось подключиться к MySQL серверу с пользователем root." unless $dbh_root;
        # cоздание пользователя
        print "CREATE USER '$mysql_user'\@'$mysql_host'\n";
        print "GRANT ALL PRIVILEGES ON $mysql_db.* TO '$mysql_user'\@'$mysql_host' IDENTIFIED BY '$mysql_pass'\n";
        $dbh_root->do("CREATE USER '$mysql_user'\@'$mysql_host'");
        $dbh_root->do("GRANT ALL PRIVILEGES ON $mysql_db.* TO '$mysql_user'\@'$mysql_host' IDENTIFIED BY '$mysql_pass'");
        # повторно проверка доступности MySQL
        $dbh = DBI->connect("DBI:mysql:host=$mysql_host;port=$mysql_port", $mysql_user, $mysql_pass);
        die "Не удалось подключиться к MySQL серверу после установки и настройки." unless $dbh;
    }
    # проверка наличия DB
    my $query = "SHOW DATABASES LIKE ?";
    my $sth = $dbh->prepare($query);
    $sth->execute($mysql_db);
    my $result = $sth->fetchrow_array;
    # если DB отсутствует, то создаем ёё
    unless ($result) { $dbh->do("CREATE DATABASE $mysql_db"); }
    #--------------------------------------------------------------------------
    color_print('type'=>'info', 'message'=>"Приготовление к работе выполнено.");
#};

# init процедуры 
sub install_cpan { # CPAN
    my $command = get_package_manager()." install -y perl-CPAN";
    system($command);
    # успешность установки
    if ($? == 0) {
        print "CPAN успешно установлен.\n";
    } else {
        die "Не удалось установить CPAN: $!\n";
    }
}
sub check_cpanm { # cpanm - проверка наличия
    my $cpanm_installed = `which cpanm`;
    chomp $cpanm_installed;
    return $cpanm_installed;
}
sub install_dependencies { # установка зависимостей из cpanfile
    App::cpanminus::script->run('--installdeps', '.');
}
sub check_curl_installed { # curl
    my $output = `curl --version 2>&1`;
    return ($output =~ /curl (\d+)/);
}
sub install_dependencies_os { # установка зависимостей
    system('curl -L https://cpanmin.us | perl - App::cpanminus');
}
sub install_curl { # curl
    my $command = get_package_manager()." install -y curl";
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
sub install_mysql { # MariaDB - colored
    my $cmd = get_package_manager();
    my $command = $cmd." update > /dev/null && ".$cmd." install -y mariadb-server > /dev/null";
    system($command);
    # успешность установки
    if ($? == 0) {
        color_print('type'=>'info', 'message'=>"MySQL успешно установлен.");
    } else {
        color_print('type'=>'error', 'message'=>"Не удалось установить MySQL: $!");
        exit;
    }
}

