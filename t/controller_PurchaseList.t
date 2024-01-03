use Test2::V0;

use lib 't/lib';
use Test::Coocook;

plan(26);

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
$t->content_like(
    qr{
        \Q<script id="shop-sections" type="application/json">\E
        \[ \{
        .+    # list content
        \} \]
        \Q</script>\E
    }x,
    "HTML contains JSON list of shop sections"
);

$t->get_ok('/project/1/Test-Project/purchase_lists');
$t->content_lacks( my $is_already_default = "Is already the default purchase list" );
$t->content_lacks( my $cant_delete        = "Can’t delete default purchase list" );

$t->max_redirect(0);

subtest "POST make_default for default list" => sub {
    ok $t->post('https://localhost/project/1/Test-Project/purchase_list/1/make_default');
    $t->status_is(302);
    $t->header_is( Location => 'https://localhost/project/1/Test-Project/purchase_lists' );
};

subtest "create list" => sub {
    ok $t->post( 'https://localhost/project/1/asfd/purchase_lists/create',
        { date => '2000-01-01', name => "second" } );
    $t->status_is(302);
    $t->header_is( Location => 'https://localhost/project/1/Test-Project/purchase_lists' );
};

$t->get_ok( $t->res->header('Location') );
$t->content_contains($is_already_default);
$t->content_contains($cant_delete);

subtest "make another list default" => sub {
    ok $t->post('https://localhost/project/1/Test-Project/purchase_list/2/make_default');
    $t->status_is(302);
    $t->header_is( Location => 'https://localhost/project/1/Test-Project/purchase_lists' );

    is $t->schema->resultset('Project')->find(1)->default_purchase_list_id => 2,
      "changed default purchase list";
};

subtest "can't delete default list of other lists exist" => sub {
    ok $t->post('/project/1/Test-Project/purchase_list/2/delete');
    $t->status_is(400);
};

for ( [ 1, "delete non-default list" ], [ 2, "delete last remaining default list" ] ) {
    my ( $id, $name ) = @$_;
    subtest $name, sub {
        ok $t->post("https://localhost/project/1/Test-Project/purchase_list/$id/delete");
        $t->status_is(302);
        $t->header_is( Location => 'https://localhost/project/1/Test-Project/purchase_lists' );
    };
}

my $project = $t->schema->resultset('Project')->find(1);
is [ $project->dishes->search_related('ingredients')->get_column('item_id')->all ] =>
  [ (undef) x 11 ],
  "all dish ingredients have no item_id";

$t->get_ok('/project/1/Test-Project/purchase_lists');

for my $date (qw< 2000-01-01 2000-01-02 >) {
    ok $t->post(
        '/project/1/Test-Project/purchase_lists/create',
        {
            date => $date,
            name => __FILE__ . " on " . $date,
        }
    );
    $t->status_is(302);
}

my ( $source_purchase_list => $target_purchase_list ) = $project->purchase_lists->all;

$project->discard_changes();
is $project->default_purchase_list_id => $source_purchase_list->id,
  "project's default_purchase_list_id was set to ID of first purchase list";

is [ $project->dishes->search_related('ingredients')->get_column('item_id')->all ] =>
  [ ( T() ) x 11 ],
  "all dish ingredients were added to items";

$t->post_ok(
    sprintf( '/project/1/Test-Project/purchase_list/%i/move_items_ingredients',
        $source_purchase_list->id ),
    {
        target_purchase_list => $target_purchase_list->id,
    }
);
$t->content_lacks( '<body', "HTML snippet, not whole page" );
