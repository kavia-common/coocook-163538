use Coocook::Base;
use Test2::V0;

use lib "t/lib";
use TestDB qw(txn_do_and_rollback);

plan( tests => 1 );

my $db = TestDB->new();

subtest recalculate => sub {
    my $dish = $db->resultset('Dish')->find(1);

    ok $dish->recalculate(6), "recalculate()";

    $dish->discard_changes();
    is $dish->servings => 6, "servings";

    is [ $dish->ingredients->hri->all ] => array {
        item hash { field value => 750;  field unit_id => 1; field article_id => 1; etc };
        item hash { field value => 7.5;  field unit_id => 1; field article_id => 2; etc };
        item hash { field value => 0.75; field unit_id => 3; field article_id => 3; etc };
    },
      "dish ingredients";

    is [ $dish->items->hri->all ] => array {
        item hash {
            field value      => 14.75;
            field offset     => 0;
            field unit_id    => 2;
            field article_id => 1;
            etc();
        };
        item hash {
            field value      => 45;
            field offset     => 5;    # offset changed!
            field unit_id    => 1;
            field article_id => 2;
            etc();
        };
        item hash {
            field value      => 2.0;
            field offset     => 0;
            field unit_id    => 3;
            field article_id => 3;
            etc();
        };
    },
      "purchase list items";
};
