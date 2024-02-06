use Test2::V0;

use lib 't/lib';
use Test::Coocook;

my $t = Test::Coocook->new( config => { enable_user_registration => 1 } );

subtest "400 Bad Request" => sub {
    ok $t->post('https://localhost/register');
    $t->status_is(400);
    $t->header_is( 'Content-Type' => 'text/html; charset=utf-8' );
    $t->content_contains('<html');
    $t->text_like(qr/bad request/i);

    $t->login_ok( 'john_doe', 'P@ssw0rd' );

    $t->post('https://localhost/project/1/Test-Project/dish/1/ingredients/create');
    $t->status_is(400);
    if ( $t->res->content_length > 0 ) {    # for something like: {"error": "bad request"}
        $t->header_is( 'Content-Type' => 'application/json; charset=utf-8' );
        $t->content_lacks('html');
    }
    else {
        $t->lacks_header_ok('Content-Type');
        $t->content_is('');
    }
};

subtest "403 Forbidden" => sub {
    $t->schema->resultset('User')->find( { name => 'john_doe' } )->roles_users->delete();
    ok $t->get('https://localhost/project/3/Other-Project');
    $t->status_is(403);
    $t->text_contains("Forbidden");
};

subtest "404 Not found" => sub {
    ok $t->get('https://localhost/doesnt-exist');
    $t->status_is(404);
    $t->text_like(qr/not found/i);

    ok $t->post('https://localhost/project/999/Test-Project/dish/999/units');
    $t->status_is(404);
    todo "Ajax" => sub {
        $t->header_is( 'Content-Type' => 'application/json' );
        $t->content_lacks('html');
    };
};

done_testing;
