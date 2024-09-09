use Coocook::Base;
use Test2::V0;

use lib "t/lib";
use TestDB qw(txn_do_and_rollback);

plan( tests => 10 );

my $db = TestDB->new();

# this is a SQL query useful debugging
# is it only run to assert that it matches the current schema
$db->storage->dbh_do( sub ( $storage, $dbh ) { $dbh->do(<<SQL) } );
SELECT
    items.id AS item_id,
    items.value,
    items.offset,
    (SELECT short_name FROM units WHERE units.id = items.unit_id) unit,
    (SELECT name FROM articles WHERE articles.id = items.article_id) article,
    di.value,
    (SELECT short_name FROM units WHERE units.id = di.unit_id) unit,
    di.id AS ingredient_id
FROM items
JOIN dish_ingredients di ON items.id = di.item_id
ORDER BY items.id
SQL

my $project = $db->resultset('Project')->find(1);
my $items   = $project->purchase_lists->find(1)->items;
my $ucg     = $project->unit_conversion_graph();
my $l       = $project->units->find( { short_name => 'l' } );
my $t       = $project->units->find( { short_name => 't' } );

{
    my $item = $items->find(1);    # repeatedly a block variable to avoid caching in Result object

    like dies { $item->remove_ingredients() } => qr/arguments/,
      "remove_ingredients() without UnitConversionGraph";

    is $item->remove_ingredients( $ucg, () ) => exact_ref($item),
      "remove_ingredients() without ingredients";
    $item->discard_changes();
    is $item->value => 14.5, "... value unchanged";
}

subtest "remove 1kg", txn_do_and_rollback $db, sub {
    my $item       = $items->find(1);
    my $ingredient = $item->ingredients->find(7);
    is $item->remove_ingredients( $ucg, $ingredient ) => exact_ref($item);
    $item->discard_changes();
    $ingredient->discard_changes();
    is $item->value => 13.5, "value decreased by 1kg";
    is $ingredient->item_id => undef;
};

subtest "remove 500g", txn_do_and_rollback $db, sub {
    my $item       = $items->find(1);
    my $ingredient = $item->ingredients->find(1);
    is $item->remove_ingredients( $ucg, $ingredient ) => exact_ref($item);
    $item->discard_changes();
    $ingredient->discard_changes();
    is $item->value => 14.0, "value decreased by 500g";
    is $ingredient->item_id => undef;
};

subtest "remove g from t", txn_do_and_rollback $db, sub {
    my $item       = $items->find(2);
    my $ingredient = $item->ingredients->find(2);

    $project->unit_conversions->results_exist(
        [
            { unit1_id => $item->unit_id, unit2_id => $t->id },
            { unit1_id => $t->id,         unit2_id => $item->unit_id },
        ]
    ) and die "tests expects no direct conversion from g to t";

    ok $item->update( { value => 1.0, unit_id => $t->id } );
    is $item->remove_ingredients( $ucg, $ingredient ) => exact_ref($item);
    $item->discard_changes();
    $ingredient->discard_changes();
    is $item->value => 0.999_995, "value decreased by 5g";
    is $ingredient->item_id => undef;
};

subtest "recalculation if removing ingredient decreases value to <0", txn_do_and_rollback $db, sub {
    my $item       = $items->find(1);
    my $ingredient = $item->ingredients->find(1);
    $item->update( { value => 42 } );
    $ingredient->update( { unit_id => $t->id } );
    is $item->remove_ingredients( $ucg, $ingredient ) => exact_ref($item);
    $item->discard_changes();
    is $item->value => 14.0, "item value recalculated";
};

my $item = $items->find(1);
$item->update( { value => 42 } );    # manipulate value
my $ingredient = $item->ingredients->create(
    {
        dish_id    => 1,
        prepare    => 0,
        value      => 1,
        unit_id    => $l->id,
        article_id => $item->article_id,
        comment    => '',
    }
);

subtest "remove l from kg (unit without conversion)", txn_do_and_rollback $db, sub {
    is $item->remove_ingredients( $ucg, $ingredient ) => exact_ref($item);
    $item->discard_changes();
    $ingredient->discard_changes();
    is $item->value => 14.5, "item value recalculated";
    is $ingredient->item_id => undef;
};

subtest "handling of l (unit without conversion) during removal", txn_do_and_rollback $db, sub {
    my $ingredient2 = $item->ingredients->find(1);
    $ingredient2->update( { unit_id => $l->id } );    # set to l to force recalculation
    $item->ingredients->update( { value => 0 } );     # value 0 must is valid, item must not be removed
    is $item->remove_ingredients( $ucg, $ingredient2 ) => exact_ref($item);
    $item->discard_changes();
    $ingredient->discard_changes();
    is $item->value                          => 0.0, "item value recalculated";
    isnt $ingredient->item_id                => $item->id, "item_id of l ingredient changed";
    is $ingredient->item->ingredients->count => 1, "new item has only 1 ingredient";
};

subtest "remove all ingredients", txn_do_and_rollback $db, sub {
    my @ingredients = $item->ingredients->all;
    is $item->remove_ingredients( $ucg, @ingredients ) => undef;
    $item->discard_changes();
    ok !$item->in_storage, "item was deleted";
    for (@ingredients) {
        $_->discard_changes();
        is $_->item_id => undef;
    }
};
