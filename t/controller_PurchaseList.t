use Test2::V0;

use lib 't/lib';
use Test::Coocook;

plan(8);

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

my $target_purchase_list = $t->schema->resultset('PurchaseList')->create(
    {
        project_id => 1,
        date       => '2000-01-01',
        name       => __FILE__,
    }
);

$t->post_ok(
    '/project/1/Test-Project/purchase_list/1/move_items_ingredients',
    {
        target_purchase_list => $target_purchase_list->id,
    }
);
$t->content_lacks( '<body', "HTML snippet, not whole page" );
