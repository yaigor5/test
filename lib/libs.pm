package MyFunctions;

our $VERSION = '1.0';
our $CREATED_DATE = '2023-05-26';

our(@EXPORT, @EXPORT_OK, %EXPORT_TAGS);
BEGIN { 
	unshift(@INC, 'lib');
	use Exporter ();
	@EXPORT = qw(
		connect_to_database
	);
	%EXPORT_TAGS = ( FIELDS => [ @EXPORT ] );
}

use strict;
use warnings;
use DBI;
use Config::IniFiles;


sub connect_to_database {
    my $config = Config::IniFiles->new(-file => 'config.ini') or die "Не удалось открыть файл config.ini: $!";
    my $mysql_host = $config->val('database', 'host');
    my $mysql_port = $config->val('database', 'port');
    my $mysql_user = $config->val('database', 'username');
    my $mysql_pass = $config->val('database', 'password');
    my $mysql_db = $config->val('database', 'dbname');
    $dbh = DBI->connect("DBI:mysql:host=$mysql_host;port=$mysql_port;database=$mysql_db", $mysql_user, $mysql_pass);
    die "Не удалось подключиться к базе данных: $DBI::errstr" unless $dbh;
    return $dbh;
}










1;