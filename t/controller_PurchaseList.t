use Test2::V0;

use lib 't/lib';
use Test::Coocook;

plan(4);

my $t = Test::Coocook->new();

$t->get('/');
$t->login_ok( 'john_doe', 'P@ssw0rd' );

$t->get_ok('/project/1/Test-Project/purchase_list/1');
$t->content_like(
    qr{
        \Q<script id="purchase-lists" type="application/json">\E
        \[ \{
        .+    # list content
        \} \]
        \Q</script>\E
    }x,
    "HTML contains JSON list of purchase lists"
);

$t->max_redirect(0);
ok $t->post('/project/1/Test-Project/purchase_list/1/make_default');
$t->status_is(302);
$t->header_is( Location => 'https://localhost/project/1/Test-Project/purchase_lists' );

$t->post_ok('/project/1/Test-Project/purchase_list/1/move_items_ingredients');
