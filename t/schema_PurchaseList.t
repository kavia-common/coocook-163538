use Test2::V0;

plan(6);

use lib 't/lib';
use TestDB qw(txn_do_and_rollback);

my $db = TestDB->new;

my $purchase_lists = $db->resultset('PurchaseList');

ok $purchase_lists->populate(
    [
        # share/test_data.sql already contains '2000-01-01'
        { project_id => 1, date => '2000-01-02', name => 'b' },
        { project_id => 1, date => '2000-01-03', name => 'c' },
    ]
  ),
  "populate";

is [ $purchase_lists->with_is_default->hri->all ] => array {
    item hash {
        field id         => 1;
        field is_default => T();
        etc();
    };
    item hash {
        field id         => 2;
        field is_default => F();
        etc();
    };
    item hash {
        field id         => 3;
        field is_default => F();
        etc();
    };
    item hash {
        field id         => 4;
        field is_default => F();
        etc();
    };
},
  "ResultSet::PurchaseList->with_is_default()";

is [ $purchase_lists->with_items_count->hri->all ] => array {
    item hash {
        field id          => 1;
        field items_count => 3;
        etc();
    };
    item hash {
        field id          => 2;
        field items_count => 1;
        etc();
    };
    item hash {
        field id          => 3;
        field items_count => 0;
        etc();
    };
    item hash {
        field id          => 4;
        field items_count => 0;
        etc();
    };
},
  "ResultSet::PurchaseList->with_items_count()";

subtest is_default => txn_do_and_rollback $db => sub {
    my @cached     = $purchase_lists->with_is_default->all;
    my @not_cached = $purchase_lists->all;

    is $cached[0]->is_default => T(), "cached true";
    is $cached[1]->is_default => F(), "cached false";

    is $not_cached[0]->is_default => T(), "not cached true";
    is $not_cached[1]->is_default => F(), "not cached false";
    @not_cached = $purchase_lists->all;    # reset project() cache

    $db->resultset('Project')->delete();

    like dies { $not_cached[$_]->is_default } => qr/undefined value/,
      "fails while trying to fetch project"
      for 0, 1;

    is $cached[0]->is_default => T(), "cached true still works";
    is $cached[1]->is_default => F(), "cached false still works";
};

subtest make_default => txn_do_and_rollback $db => sub {
    my $list1 = $purchase_lists->find(1);
    my $list2 = $purchase_lists->find(2);

    ok $list1->is_default;
    is $list2->make_default => exact_ref($list2);
    ok $list2->is_default;
};

subtest delete => sub {
    my $list1 = $purchase_lists->find(1);
    my $list2 = $purchase_lists->find(2);

    my $original_items1       = $list1->items->count;
    my $original_items2       = $list2->items->count;
    my $original_ingredients1 = $list1->ingredients->count;
    my $original_ingredients2 = $list2->ingredients->count;

    $list1->move_items_ingredients(
        target_purchase_list => $list2,
        ingredients          => [],
        items                => [ $list1->items->one_row ],
        ucg                  => $list1->project->unit_conversion_graph,
    );

    cmp_ok $list1->items->count,       '<', $original_items1;
    cmp_ok $list1->ingredients->count, '<', $original_ingredients1;

    cmp_ok $list2->ingredients->count, '>', 0;

    ok $list2->delete();

    is $list1->items->count       => $original_items1 + $original_items2;
    is $list1->ingredients->count => $original_ingredients1 + $original_ingredients2;

    like dies { $list1->delete() } => qr/Purchase list is default list/;
    ok $list1->other_purchase_lists->delete();
    ok $list1->delete();

    $list1->insert();
    cmp_ok $list1->ingredients->count, '==', $original_ingredients1 + $original_ingredients2;
    cmp_ok $list1->items->count, '>=',    # different units not merged
      $original_items1 + $original_items2;
};
