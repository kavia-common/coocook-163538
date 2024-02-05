use Test2::V0;

use lib 't/lib';
use Test::Coocook;

plan(14);

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

note "Deleting all purchase lists ...";
my $project = $t->schema->resultset('Project')->find(1);
$project->update( { default_purchase_list_id => undef } );
$project->purchase_lists->delete();

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

$t->post_ok(
    sprintf( '/project/1/Test-Project/purchase_list/%i/move_items_ingredients',
        $source_purchase_list->id ),
    {
        target_purchase_list => $target_purchase_list->id,
    }
);
$t->content_lacks( '<body', "HTML snippet, not whole page" );
