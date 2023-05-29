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
use DateTime::Format::MySQL;
use Data::Dump qw(dump);

# процедура для подключения к БД
sub connect_to_database {
    # считывание конфига
    my $config = Config::IniFiles->new(-file => 'config.ini') or die "Не удалось открыть файл config.ini: $!";
    my $mysql_host = $config->val('database', 'host');
    my $mysql_port = $config->val('database', 'port');
    my $mysql_user = $config->val('database', 'username');
    my $mysql_pass = $config->val('database', 'password');
    my $mysql_db = $config->val('database', 'dbname');
    # дескриптор
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
    my $res=$sth->fetchrow_array;
    
    ## debug
    print dump($res)."\n";
    exit;

    return $res;
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
    my $schema_log = "
    CREATE TABLE IF NOT EXISTS `log` (
    `created` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
    `int_id` char(16) NOT NULL,
    `str` text DEFAULT NULL,
    `address` varchar(255) DEFAULT NULL,
    KEY `log_address_idx` (`address`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ";
    
    # структура таблицы 'message'
    my $schema_message = "
    CREATE TABLE IF NOT EXISTS `message` (
    `created` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
    `id` varchar(255) NOT NULL,
    `int_id` char(16) NOT NULL,
    `str` text NOT NULL,
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

## TODO - bootstrap view
# под-процедура для построчного распарсивания и записи в БД
sub log_line_parser {
    my ($dbh, $log_line, $message_insert_sth, $log_insert_sth) = @_;

    # парсинг строки
    my @fields = parse_line(' ', 0, $log_line);

    # обработка явных некорректностей
    if (!$fields[0] || $fields[0]!~/^\d{4}\-\d{2}\-\d{2}/) {
        print "В этой строке лога некорректный формат - проблема с timestamp.\n";
        return;
    }
    if (!$fields[2]) {
        print "В этой строке лога некорректный формат - нет внутреннего id.\n";
        return;
    }

    # создание хэша
    my %log_data;
    my $dt=DateTime::Format::MySQL->parse_datetime("$fields[0] $fields[1]");
    $log_data{created} = DateTime::Format::MySQL->format_datetime($dt); # = timestamp строки лога
    $log_data{int_id} = $fields[2]; # = внутренний id сообщения
    $log_data{str} = join(' ', @fields[2..$#fields]); # = строка лога (без временной метки)
    $log_data{tbl}='log'; # - определено условием

    # обработка флага в строке
    if (defined $fields[3]) { # есть флаг
        $log_data{flag}=chomp($fields[3]);
        if ($log_data{flag} eq '<=') { # прибытие сообщения (в этом случае за флагом следует адрес отправителя)
            #$log_data{from}=$fields[4]; # адрес отправителя - нигде не используется
            if ($log_data{str} =~ /\sid=(\S+)\s/) { # поиск значения id=xxxx - только для входящих - определено условием
                $log_data{id} = $1; # = значение поля id=xxxx из строки лога
            } 
            $log_data{tbl}='message'; # into message table - определено условием
        } elsif ($log_data{flag} eq '=>') { # нормальная доставка сообщения
            $log_data{to}=$fields[4]; # адрес получателя
        } elsif ($log_data{flag} eq '->') { # дополнительный адрес в той же доставке
            $log_data{to}=$fields[4]; # адрес получателя
        } elsif ($log_data{flag} eq '**') { # доставка не удалась
            $log_data{to}=$fields[4]; # адрес получателя
        } elsif ($log_data{flag} eq '==') { # доставка задержана (временная проблема)
            $log_data{to}=$fields[4]; # адрес получателя
        } else { # В случаях, когда в лог пишется общая информация, флаг и адрес получателя не указываются
            ##print "В этой строке лога общая информация.\n";
        }
    } else { 
        print "В этой строке лога неполный формат - нет данных.\n";
    }

    # В таблицу 'message' должны попасть только строки прибытия сообщения (с флагом '<='').
    # В таблицу 'log' записываются все остальные строки - таким образом по условию исключаются сообщения прибытия из 'log'

    # распределение хэша в БД
    if ($log_data{tbl} eq 'message') {
        $$message_insert_sth->execute($log_data{created}, $log_data{int_id}, $log_data{str}, $log_data{id});
    } else {
        $$log_insert_sth->execute($log_data{created}, $log_data{int_id}, $log_data{str}, $log_data{to});
    }

}

## TODO - bootstrap view
# основная процедура для парсинга лога
sub log_parser {
    # считывание конфига
    my $config = Config::IniFiles->new(-file => 'config.ini') or die "Не удалось открыть файл config.ini: $!";
    my $log_file=$config->val('log', 'path')."/".$config->val('log', 'filename');

    if ($config->val('flag', 'done')) { 
        print "Уже считывали данные из лог файла\n";
        return; 
    }

    my $dbh=connect_to_database();

    # Подготовка SQL-запросов для вставки данных в таблицы
    my $message_insert_sth = $dbh->prepare('INSERT INTO `message` (`created`, `int_id`, `str`, `id`) VALUES (?, ?, ?, ?)');
    my $log_insert_sth = $dbh->prepare('INSERT INTO `log` (`created`, `int_id`, `str`, `address`) VALUES (?, ?, ?, ?)');

    # открытие файла лога
    open(my $fh, '<', $log_file) or die "Can't open $log_file: $!";

    # чтение файла лога и обработка построчно
    while (my $line = <$fh>) {
        chomp($line);
        log_line_parser($dbh,$line,\$message_insert_sth,\$log_insert_sth);
    }

    # закрытие соединений
    close($fh);
    $dbh->disconnect();

    # сохранение флага в конфиге
    $config->setval('flag', 'done', '1');
    $config->RewriteConfig();

}



1;