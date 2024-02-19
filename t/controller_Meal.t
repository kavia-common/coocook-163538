use Test2::V0;

use lib 't/lib';
use Test::Coocook;

plan(16);

my $t = Test::Coocook->new();

$t->get('/');
$t->login_ok( 'john_doe', 'P@ssw0rd' );

$t->post_ok(
    '/project/1/Test-Project/meals/create',
    {
        date    => '2000-01-01',
        name    => 'meal from test',
        comment => __FILE__,
    }
);

$t->json_is(
    {
        meal => hash {
            field id   => 10;
            field name => 'meal from test';
            etc();
        },
    }
);

ok $t->post( '/project/1/Test-Project/meals/10/update', {} ), "POST /update with empty JSON";
$t->status_is(400);

ok $t->post( '/project/1/Test-Project/meals/10/update', { date => 'foo' } ),
  "POST /update with invalid date";
$t->status_is(400);
$t->json_is( { error => { message => match qr/invalid date string/ } } );

ok $t->post(
    '/project/1/Test-Project/meals/10/update',
    { date => '2000-01-01', name => 'breakfast' }
  ),
  "POST /update with existing date and name";
$t->status_is(400);
$t->json_is( { error => { message => match qr/same name on same date/ } } );

ok $t->post('/project/1/Test-Project/meals/1/delete'), "POST /delete on meal with dishes";
$t->status_is(400);
$t->json_is( { error => { message => match qr/cannot be deleted/ } } );

$t->post_ok('/project/1/Test-Project/meals/10/delete');
ok !$t->schema->resultset('Meal')->find(10), "meal not found in database anymore";
