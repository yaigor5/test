package Lib1;

our $VERSION = '1.2';
our $CREATED_DATE = '2023-05-26';

use strict;
use warnings;
use DBI;
use Config::IniFiles;
use Text::ParseWords;
use DateTime::Format::MySQL;
use Data::Dump qw(dump);

# процедура для получения парметров для вьюшки
sub html_config {
    # Описание:
    # Функция получает данные из секции [html] в 'config.ini'.
    #
    # Входные параметры:
    # Отсутствуют.
    #
    # Возвращаемое значение:
    # Хэш с параметрами.
    #
    # Действие функции:
    # 1. Считывание конфигурационного файла 'config.ini'.
    # 2. Получение параметров из конфигурационного файла.

    my %tt = ();
    # считывание конфига
    my $config = Config::IniFiles->new(-file => 'config.ini') or die "Не удалось открыть файл config.ini: $!";
    $tt{'max'} = $config->val('html', 'max_elements');
    $tt{'debug'} = $config->val('html', 'debug');

    return %tt;
}

# процедура для подключения к БД
sub connect_to_database {
    # Описание:
    # Функция устанавливает соединение с базой данных.
    #
    # Входные параметры:
    # Отсутствуют.
    #
    # Возвращаемое значение:
    # Дескриптор соединения с базой данных.
    #
    # Действие функции:
    # 1. Считывание конфигурационного файла 'config.ini'.
    # 2. Получение параметров подключения к базе данных из конфигурационного файла.
    # 3. Установка соединения с базой данных.
    # 4. В случае ошибки соединения, выводится сообщение об ошибке.

    # считывание конфига
    my $config = Config::IniFiles->new(-file => 'config.ini') or die "Не удалось открыть файл config.ini: $!";
    my $mysql_host = $config->val('database', 'host');
    my $mysql_port = $config->val('database', 'port');
    my $mysql_user = $config->val('database', 'username');
    my $mysql_pass = $config->val('database', 'password');
    my $mysql_db = $config->val('database', 'dbname');
    # дескриптор
    my $dsn = "DBI:mysql:host=$mysql_host;port=$mysql_port;database=$mysql_db;charset=utf8";
    my $dbh = DBI->connect($dsn, $mysql_user, $mysql_pass, { mysql_enable_utf8 => 1 });
    die "Не удалось подключиться к базе данных: $DBI::errstr" unless $dbh;
    return $dbh;
}

# процедура для отключения от БД
sub disconnect_from_database {
    # Описание:
    # Функция отключается от базы данных.
    #
    # Входные параметры:
    # $dbh - дескриптор соединения с базой данных.
    #
    # Возвращаемое значение:
    # Отсутствуют.
    #
    # Действие функции:
    # 1. Закрытие соединения с базой данных.

    my ($dbh) = @_;
    $dbh->disconnect;
}

## TODO - bootstrap view
# под-процедура для проверки существования таблицы и создания при отсутствии
sub check_and_create_table {
    # Описание:
    # Функция проверяет существование таблицы в базе данных и создает ее при отсутствии.
    #
    # Входные параметры:
    # $dbh - дескриптор соединения с базой данных.
    # $table_name - название таблицы.
    # $table_schema - схема таблицы.
    #
    # Возвращаемое значение:
    # Отсутствует.
    #
    # Действие функции:
    # 1. Проверка существования таблицы в базе данных.
    # 2. В случае отсутствия таблицы, создание таблицы с заданной схемой.

    my ($dbh, $table_name, $table_schema) = @_;
    if (!check_table_exists($dbh, $table_name)) {
        create_table($dbh, $table_name, $table_schema);
        print "Таблица '$table_name' создана\n";
    }
}

# под-процедура для проверки существования таблицы
sub check_table_exists {
    # Описание:
    # Функция выполняет SQL-запрос к базе данных и возвращает результат.
    #
    # Входные параметры:
    # $dbh - дескриптор соединения с базой данных.
    # $sql_query - SQL-запрос.
    #
    # Возвращаемое значение:
    # Результат выполнения SQL-запроса.
    #
    # Действие функции:
    # 1. Проверяет существование таблицы с именем из $table_name.
    # 2. Возвращает результат выполнения [0|1].

    my ($dbh, $table_name) = @_;
    my $sth = $dbh->prepare("SELECT count(*) FROM `information_schema`.`tables` WHERE `table_name`='".$table_name."'");
    $sth->execute();
    return $sth->fetchrow_array;
}

## TODO - bootstrap view
# под-процедура для создания таблицы
sub create_table {
    # Описание:
    # Функция создает новую таблицу в базе данных с заданным именем и схемой.
    #
    # Входные параметры:
    # $dbh - объект DBI, представляющий соединение с базой данных.
    # $table_name - имя таблицы.
    # $table_schema - схема таблицы.
    #
    # Возвращаемое значение:
    # Отсутствует.
    #
    # Действие функции:
    # 1. Выполняет SQL-запрос с использованием метода do объекта DBI.
    # 2. Обрабатывает ошибку при выполнении SQL-запроса и выводит сообщение об ошибке.

    my ($dbh, $table_name, $table_schema) = @_;
    $dbh->do($table_schema) or die "Не удалось создать таблицу '$table_name': $dbh->errstr";
}

# основная процедура для проверка и создание структуры таблиц
sub check_and_prepare_sql_structure {
    # Описание:
    # Функция проверяет и подготавливает структуру SQL-запроса перед выполнением.
    #
    # Входные параметры:
    # Отсутствуют.
    #
    # Возвращаемое значение:
    # Отсутствует.
    #
    # Описание действий функции:
    # 1. Проверяет наличие таблицы 'log' и создает структуру при отсутствии
    # 2. Проверяет наличие таблицы 'message' и создает структуру при отсутствии

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
    # Описание:
    # Функция разбирает строку журнала и подставляет результат в заранее подготовленные формы запросов к БД.
    #
    # Входные параметры:
    # $log_line - строка журнала.
    #
    # Возвращаемое значение:
    # Изменение подготовленных переменных $message_insert_sth, $log_insert_sth в зависимости от результата парсинга.
    #
    # Описание действий функции:
    # 1. Разделяет строку журнала на поля с использованием разделителя ' ' предварительно экранируя одинарные кавычки (деэкранируя в конце).
    # 2. Создает переменные для каждого значимого поля и присваивает им значения из разделенных полей.
    # 3. Подставляет структурированные данные из хэша в подготовленные переменные для запросов к БД и выполняет их.

    my ($dbh, $log_line, $message_insert_sth, $log_insert_sth) = @_;

    # экранирование '
    $log_line =~ s/'/\\'/g;

    # парсинг строки
    my @fields = parse_line(' ', 0, $log_line);

    # обработка явных некорректностей
    if (! defined $fields[0] || ! defined $fields[1]) {
        print "В этой строке лога некорректный формат - проблема с timestamp:\n$log_line\n";
        ## debug
        for (@fields) { print "'".$_."'\n"; }
        exit;

        return;
    }
    if (!$fields[2]) {
        print "В этой строке лога некорректный формат - нет внутреннего id:\n$log_line\n";
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
        $log_data{flag}=$fields[3];
        if ($log_data{flag} eq '<=') { # прибытие сообщения (в этом случае за флагом следует адрес отправителя)
            #$log_data{from}=$fields[4]; # адрес отправителя - нигде не используется
            for (@fields) { # поиск значения id=xxxx - только для входящих - определено условием
                if ($_=~/^id=(.*)$/) { 
                    $log_data{id} = $1; # = значение поля id=xxxx из строки лога
                }
            }
            if (!$log_data{id}) { # отбрасываем - эту строку невозможно добавить в таблицу без 'id'
                return; 
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
        print "В этой строке лога неполный формат - нет данных:\n$log_line\n";
    }

    # В таблицу 'message' должны попасть только строки прибытия сообщения (с флагом '<='').
    # В таблицу 'log' записываются все остальные строки - таким образом по условию исключаются сообщения прибытия из 'log'

    # возврат '
    my @words = quotewords('\s+', 1, $log_data{str});
    $log_data{str}= join(" ", @words);

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
    # Описание:
    # Функция анализирует файл журнала, парсит каждую строку и возвращает массив структурированных данных.
    #
    # Входные параметры:
    # Отсутствуют.
    #
    # Возвращаемое значение:
    # Отсутствует.
    #
    # Описание действий функции:
    # 1. Считывает путь к файлу журнала в $log_file.
    # 2. Проверяет значение флага 'done' из секции 'flag' файла конфигурации.
    # 3. Открывает файл журнала для чтения при условии первичного разбора.
    # 4. Читает файл построчно и передает каждую строку в функцию log_line_parser для парсинга и занесения в БД.
    # 6. Закрывает файл журнала.
    # 7. Записывает о факте обработки флаг 'done' из секции 'flag' файла конфигурации.

    # считывание конфига
    my $config = Config::IniFiles->new(-file => 'config.ini') or die "Не удалось открыть файл config.ini: $!";
    my $log_file=$config->val('log', 'path')."/".$config->val('log', 'filename');

    if ($config->val('flag', 'done')) { 
        print "Уже считывали данные из лог файла\n";
        return; 
    }

    my $dbh=connect_to_database();
    my $i;
    # Подготовка SQL-запросов для вставки данных в таблицы
    my $message_insert_sth = $dbh->prepare('INSERT INTO `message` (`created`, `int_id`, `str`, `id`) VALUES (?, ?, ?, ?)');
    my $log_insert_sth = $dbh->prepare('INSERT INTO `log` (`created`, `int_id`, `str`, `address`) VALUES (?, ?, ?, ?)');

    # открытие файла лога
    open(my $fh, '<', $log_file) or die "Can't open $log_file: $!";

    # чтение файла лога и обработка построчно
    while (my $line = <$fh>) {
        chomp($line);
        log_line_parser($dbh,$line,\$message_insert_sth,\$log_insert_sth);
        # подсчет
        $i++;
    }

    # закрытие соединений
    close($fh);
    $dbh->disconnect();

    # сохранение флага в конфиге
    $config->setval('flag', 'done', '1');
    $config->setval('flag', 'counter', $i);
    $config->RewriteConfig();

}

sub trim {
    # Описание:
    # Функция очищает лишние пробелы по краям строк(и).
    #
    # Входные параметры:
    # Строка или массив.
    #
    # Возвращаемое значение:
    # Очищенные данные.
    #
    # Описание действий функции:
    # 1. Удаляет для всех строк (строки) пробелы в начале и в конце.

    my($string)=@_;
    for ($string) {
        s/^\s+//;
        s/\s+$//;
        }
    return $string;
}

=head1 DESCRIPTION

Lib1 - это модуль Perl, который предоставляет функции для подключения к базе данных, проверки и создания структуры таблицы и разбора файлов журнала.

=cut


1;