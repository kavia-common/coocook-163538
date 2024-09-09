use Test2::V0;

use lib 't/lib';
use Test::Coocook;

plan(4);

my $t = Test::Coocook->new();

$t->get_ok('/');
$t->login_ok( 'john_doe', 'P@ssw0rd' );

subtest users => sub {
    $t->get_ok('/autocomplete/users?search=o');
    $t->status_is(200);
    $t->header_is( 'Content-Type' => 'application/json; charset=utf-8' );
    $t->json_is(
        [
            { name => "john_doe", display_name => "John Doe" },
            { name => "other",    display_name => "Other User" },
        ]
    );

    $t->get_ok('/autocomplete/users?search=zzz');
    $t->status_is(200);
    $t->header_is( 'Content-Type' => 'application/json; charset=utf-8' );
    $t->json_is( [] );

    $t->get('/autocomplete/users');
    $t->status_is(400);
};

subtest organizations_users => sub {
    $t->get_ok('/autocomplete/organizations_users?search=s');
    $t->status_is(200);
    $t->header_is( 'Content-Type' => 'application/json; charset=utf-8' );
    $t->json_is(
        [
            { type => 'user',         name => 'other',    display_name => 'Other User' },
            { type => 'organization', name => 'TestData', display_name => 'Test Data' },
        ]
    );

    $t->get_ok('/autocomplete/organizations_users?search=zzz');
    $t->status_is(200);
    $t->header_is( 'Content-Type' => 'application/json; charset=utf-8' );
    $t->json_is( [] );

    $t->get('/autocomplete/organizations_users');
    $t->status_is(400);
};
