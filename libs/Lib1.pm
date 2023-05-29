package Lib1;

our $VERSION = '1.0';
our $CREATED_DATE = '2023-05-26';

#our(@EXPORT, @EXPORT_OK, %EXPORT_TAGS);
#BEGIN { 
#	unshift(@INC, 'libs');
#	use Exporter ();
#	@EXPORT = qw(
#		connect_to_database
#	);
#	%EXPORT_TAGS = ( FIELDS => [ @EXPORT ] );
#}

use strict;
use warnings;
use DBI;
use Config::IniFiles;
use Text::ParseWords;

# процедура для подключения к БД
sub connect_to_database {
    my $config = Config::IniFiles->new(-file => 'config.ini') or die "Не удалось открыть файл config.ini: $!";
    my $mysql_host = $config->val('database', 'host');
    my $mysql_port = $config->val('database', 'port');
    my $mysql_user = $config->val('database', 'username');
    my $mysql_pass = $config->val('database', 'password');
    my $mysql_db = $config->val('database', 'dbname');
    my $dbh = DBI->connect("DBI:mysql:host=$mysql_host;port=$mysql_port;database=$mysql_db", $mysql_user, $mysql_pass);
    die "Не удалось подключиться к базе данных: $DBI::errstr" unless $dbh;
    return $dbh;
}

# процедура для отключения от БД
sub disconnect_from_database {
    my ($dbh) = @_;
    $dbh->disconnect;
}

## TODO - bootstrap view
# под-процедура для проверки существования таблицы и создания при отсутствии
sub check_and_create_table {
    my ($dbh, $table_name, $table_schema) = @_;
    if (!check_table_exists($dbh, $table_name)) {
        create_table($dbh, $table_name, $table_schema);
        print "Таблица '$table_name' создана\n";
    }
}

# под-процедура для проверки существования таблицы
sub check_table_exists {
    my ($dbh, $table_name) = @_;
    my $sth = $dbh->table_info(undef, undef, $table_name, 'TABLE');
    $sth->execute();
    return $sth->fetchrow_array;
}

## TODO - bootstrap view
# под-процедура для создания таблицы
sub create_table {
    my ($dbh, $table_name, $table_schema) = @_;
    $dbh->do($table_schema) or die "Не удалось создать таблицу '$table_name': $dbh->errstr";
}

# основная процедура для проверка и создание структуры таблиц
sub check_and_prepare_sql_structure {
    # структура таблицы 'log'
    $schema_log = "
    CREATE TABLE IF NOT EXISTS `log` (
    `created` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
    `int_id` char(16) NOT NULL,
    `str` varchar(255) DEFAULT NULL,
    `address` varchar(255) DEFAULT NULL,
    KEY `log_address_idx` (`address`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";
    
    # структура таблицы 'message'
    $schema_message = "
    CREATE TABLE IF NOT EXISTS `message` (
    `created` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
    `id` varchar(255) NOT NULL,
    `int_id` char(16) NOT NULL,
    `str` varchar(255) NOT NULL,
    `status` tinyint(1) DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `message_created_idx` (`created`),
    KEY `message_int_id_idx` (`int_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";

    my $dbh=connect_to_database();
    # проверка и создание таблицы 'log'
    check_and_create_table($dbh, 'log', $schema_log);

    # проверка и создание таблицы 'message'
    check_and_create_table($dbh, 'message', $schema_message);

    # Закрытие соединения с базой данных
    disconnect_from_database($dbh);
}

# под-процедура для построчного распарсивания
sub log_line_parser {
    #my ($dbh, $log_line) = @_;

    my $log_line = '2012-02-13 14:39:22 1RwtJa-000AFB-07 => :blackhole: <tpxmuwr@somehost.ru> R=blackhole_router';
    my @fields = parse_line(' ', 0, $log_line);

    # создание именного хэша
    my %log_data;
    $log_data{created} = "$fields[0] $fields[1]";
    $log_data{int_id} = $fields[2];
    $log_data{str} = join(' ', @fields[3..$#fields]);

    # поиск значения id=xxx
    if ($log_data{str} =~ /id=(\S+)/) {
        $log_data{id} = $1;
    }    
}



1;