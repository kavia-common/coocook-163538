use Test2::V0;

use lib 't/lib';
use TestDB;

my $db = TestDB->new;

subtest duplicate => sub {
    my $recipe = $db->resultset('Recipe')->find(1);

    ok my $clone = $recipe->duplicate( { name => 'clone recipe' } ), "clone";

    isa_ok $clone => 'Coocook::Schema::Result::Recipe';

    isnt $clone->id => $recipe->id, "IDs differ";

    is $clone->ingredients->count => $recipe->ingredients->count, "number of ingredients equal";
};

subtest recalculate => sub {
    my $recipe = $db->resultset('Recipe')->find(1);

    ok $recipe->recalculate(6), "recalculate()";

    is [ $recipe->ingredients->hri->all ] => array {
        item hash { field value => 22.5; field unit_id => 1; field article_id => 2; etc };
        item hash { field value => 1.5;  field unit_id => 2; field article_id => 1; etc };
        item hash { field value => 0.75; field unit_id => 3; field article_id => 3; etc };
        item hash { field value => 15;   field unit_id => 1; field article_id => 2; etc };
    },
      "recipe ingredients";
};

done_testing;
