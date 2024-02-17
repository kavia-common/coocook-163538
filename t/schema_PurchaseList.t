use Test2::V0;

plan(5);

use lib 't/lib';
use TestDB qw(txn_do_and_rollback);

my $db = TestDB->new;

my $rs = $db->resultset('PurchaseList');

ok $rs->populate(
    [
        { project_id => 1, date => '2000-01-01', name => 'a' },
        { project_id => 1, date => '2000-01-02', name => 'b' },
        { project_id => 1, date => '2000-01-03', name => 'c' },
    ]
  ),
  "populate";

is [ $rs->with_is_default->hri->all ] => array {
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

is [ $rs->with_items_count->hri->all ] => array {
    item hash {
        field id          => 1;
        field items_count => 4;
        etc();
    };
    item hash {
        field id          => 2;
        field items_count => 0;
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
    my @cached     = $rs->with_is_default->all;
    my @not_cached = $rs->all;

    is $cached[0]->is_default => T(), "cached true";
    is $cached[1]->is_default => F(), "cached false";

    is $not_cached[0]->is_default => T(), "not cached true";
    is $not_cached[1]->is_default => F(), "not cached false";
    @not_cached = $rs->all;    # reset project() cache

    $db->resultset('Project')->delete();

    like dies { $not_cached[$_]->is_default } => qr/undefined value/,
      "fails while trying to fetch project"
      for 0, 1;

    is $cached[0]->is_default => T(), "cached true still works";
    is $cached[1]->is_default => F(), "cached false still works";
};

subtest make_default => sub {
    my $list1 = $rs->find(1);
    my $list2 = $rs->find(2);

    ok $list1->is_default;
    is $list2->make_default => exact_ref($list2);
    ok $list2->is_default;
};
