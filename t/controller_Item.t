use Test2::V0;

use lib 't/lib';
use Test::Coocook;

plan(5);

my $t = Test::Coocook->new();

# the project needs >=2 purchase lists to move ingredients
$t->schema->resultset('PurchaseList')
  ->create( { project_id => 1, date => '2000-01-01', name => __FILE__ } );

$t->get('/');
$t->login_ok( 'john_doe', 'P@ssw0rd' );

subtest "change item total" => sub {
    $t->get_ok('/project/1/Test-Project/purchase_list/1');

    $t->content_contains( my $original_value = 'value="43"' );
    $t->text_contains( "\N{PLUS SIGN}0.5\N{THIN SPACE}g" . "rounding difference" );

    $t->submit_form_ok(
        {
            form_name   => 'total',
            form_number => 6,
            with_fields => { total => 40 },
        },
        "Set total value to 40"
    );

    $t->get_ok('/project/1/Test-Project/purchase_list/1');

    $t->content_lacks($original_value);

    $t->content_contains('value="40"');
    $t->text_contains( "\N{MINUS SIGN}2.5\N{THIN SPACE}g" . "rounding difference" );
};

subtest "remove offset" => sub {
    $t->content_lacks( my $new_value              = 'value="42.5"' );
    $t->content_contains( my $rounding_difference = 'rounding difference' );

    $t->submit_form_ok(
        {
            form_name   => 'remove-offset',
            form_number => 9,
            button      => 'offset',
        },
        "Remove offset"
    );

    $t->content_contains($new_value);
    $t->content_lacks($rounding_difference);
};

subtest "remove ingredient" => sub {
    $t->content_contains( my $value  = '14.5' );
    $t->content_lacks( my $form_name = 'remove-ingredient',
        "Ingredients from default purchase list can't be removed" );

    note "Making purchase list 2 the default list ...";
    $t->schema->resultset('Project')->find(1)->update( { default_purchase_list_id => 2 } );
    $t->reload_ok();

    $t->submit_form_ok(
        {
            form_name   => $form_name,
            form_number => 6,
        },
        "Remove ingredient"
    );

    $t->content_lacks($value);
};

subtest "convert item" => sub {
    $t->text_contains("14\N{THIN SPACE}kilograms");
    $t->content_contains( my $old_value = 'value="14"' );
    $t->content_lacks( my $new_value    = 'value="14000"' );

    $t->submit_form_ok( { form_number => 4 }, "Convert item to g" );
    $t->content_lacks($old_value);
    $t->content_contains($new_value);
    $t->text_contains("14000\N{THIN SPACE}grams");
};
