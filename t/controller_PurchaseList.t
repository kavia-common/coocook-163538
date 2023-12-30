use Test2::V0;

use lib 't/lib';
use Test::Coocook;

plan(3);

my $t = Test::Coocook->new();

$t->get('/');
$t->login_ok( 'john_doe', 'P@ssw0rd' );

$t->get_ok('/project/1/Test-Project/purchase_list/1');

$t->post_ok('/project/1/Test-Project/purchase_list/1/move_items_ingredients');
