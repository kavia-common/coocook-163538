use Test2::V0;

no feature 'indirect';

use Coocook::Schema;
use Coocook::Script::Deploy;

use lib 't/lib';
use TestDB;
use Test::Coocook;    # makes Coocook::Script::Deploy not read real config files

plan(5);

my $schema = TestDB->new( deploy => 0 );

try_ok {
    Coocook::Script::Deploy->new(
        _schema    => $schema,
        target     => 1,
        extra_argv => ['install'],
    )->run()
}
"install version 1";

try_ok {
    Coocook::Script::Deploy->new(
        _schema    => $schema,
        target     => 2,
        extra_argv => ['upgrade'],
    )->run()
}
"upgrade to version 2";

ok my $app = Coocook::Script::Deploy->new(
    _schema    => $schema,
    extra_argv => ['upgrade'],
);

try_ok { $app->run() } "upgrade to current version";

is $app->_dh->database_version => $Coocook::Schema::VERSION, "reached current schema version";
