use Test2::V0;

use lib 't/lib';
use Test::Coocook;

plan(2);

my $t = Test::Coocook->new();

# the project needs >=2 purchase lists to move ingredients
$t->schema->resultset('PurchaseList')
  ->create( { project_id => 1, date => '2000-01-01', name => __FILE__ } );

$t->get('/');
$t->login_ok( 'john_doe', 'P@ssw0rd' );

{    # TODO maybe this could be done via HTML
    my $ingredient = $t->schema->resultset('DishIngredient')->find(2);
    my $list       = $t->schema->resultset('PurchaseList')->find(1);
    $ingredient->assign_to_purchase_list($list);
}

subtest "change item total" => sub {
    $t->get_ok('/project/1/Test-Project/purchase_list/1');

    $t->content_contains( my $original_value = 'value="43"' );

    $t->submit_form_ok(
        {
            form_name   => 'total',
            form_number => 5,
            with_fields => { total => 39 },
        },
        "Set total value to 39"
    );

    $t->get_ok('/project/1/Test-Project/purchase_list/1');

    $t->content_lacks($original_value);

    $t->content_contains('value="39"');

    $t->text_contains( "\N{MINUS SIGN}3.5\N{THIN SPACE}g" . "rounding difference" );

    $t->submit_form_ok(
        {
            form_name   => 'remove-offset',
            form_number => 6,
            button      => 'offset',
        },
        "Remove offset"
    );

    $t->get_ok('/project/1/Test-Project/purchase_list/1');

    $t->content_lacks('rounding difference');

    $t->content_contains('value="42.5"');

    $t->content_contains('12.5');

    $t->content_lacks('30');

    $t->content_lacks( 'remove-ingredient', "Ingredients from default purchase list can't be removed" );

    note "Making purchase list 2 the default list ...";
    $t->schema->resultset('Project')->find(1)->update( { default_purchase_list_id => 2 } );

    $t->reload_ok();

    $t->submit_form_ok(
        {
            form_name   => 'remove-ingredient',
            form_number => 9,
        },
        "Remove ingredient"
    );

    $t->content_lacks('12.5');

    $t->content_contains('30');

    $t->content_contains('value="1000"');

    $t->content_lacks('value="1"');

    $t->submit_form_ok(
        {
            form_number => 4,
            button      => 'unit',
        },
        "Convert item to kg"
    );

    $t->content_lacks('value="1000"');

    $t->content_contains('value="1"');

};
