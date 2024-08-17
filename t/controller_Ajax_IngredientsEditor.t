use Coocook::Base;

use Test2::V0;
use Test::Builder;

use lib 't/lib';
use TestDB qw(txn_do_and_rollback);
use Test::Coocook;

plan(8);

my $t = Test::Coocook->new;

$t->get_ok('/');
$t->login_ok( 'john_doe', 'P@ssw0rd' );

for my $entity (qw( articles ingredients units )) {
    subtest $entity => sub {
        $t->get_ok("https://localhost/project/1/Test-Project/dish/1/$entity");
        $t->header_is( 'Content-Type' => 'application/json; charset=utf-8' );
        $t->content_lacks('html');
        $t->content_like(qr/ \A \[ \{ /x);
    };
}

my $ingredients = $t->schema->resultset('DishIngredient');

subtest "upgrade_ingredient", txn_do_and_rollback $t->schema, sub {
    ok $t->post('https://localhost/project/1/Test-Project/dish/999/ingredients/update');
    $t->status_is(404);

    my $ingredient = $ingredients->find(2);
    $ingredient->unit->short_name eq ( my $original_unit = 'g' ) or die "test broken";

    my $item = $ingredient->item;
    $item->total == 50 or die "test broken";

    my $json = {
        ingredient => {
            id           => 2,
            value        => my $value = 7.5,    # 5.0 -> 0.0075 (=7.5g)
            current_unit => { id => 2 },        # g -> kg
            comment      => my $comment = __FILE__,
        }
    };

    {
        local $json->{ingredient}{id} = 999;
        ok $t->post_json( 'https://localhost/project/1/Test-Project/dish/1/ingredients/update', $json );
        $t->status_is(404);
    }

    {
        my $other_unit = $t->schema->resultset('Project')->find(2)->units->one_row;
        local $json->{ingredient}{current_unit}{id} = $other_unit->id;
        ok $t->post_json( 'https://localhost/project/1/Test-Project/dish/1/ingredients/update', $json );
        $t->status_is(400);
    }
    $ingredient->discard_changes();
    is $ingredient->unit->short_name => $original_unit, "... unit_id wasn't changed";

    ok $t->post_json( 'https://localhost/project/1/Test-Project/dish/1/ingredients/update', $json );
    $t->status_is(200);
    $t->json_is( { id => $ingredient->id } );
    $ingredient->discard_changes();
    is $ingredient->value            => $value, "value";
    is $ingredient->unit->short_name => 'kg', "unit";
    is $ingredient->comment          => $comment, "comment";
};

subtest "handling of offset on purchase list items", txn_do_and_rollback $t->schema => sub {
    my $ingredient = $ingredients->create(
        {
            dish_id    => 1,
            prepare    => 1,
            value      => 0,
            unit_id    => 1,
            article_id => 1,
            comment    => __FILE__,
            item       => {
                purchase_list_id => 1,
                value            => 0,
                offset           => 0,
                unit_id          => 1,
                article_id       => 1,
                comment          => __FILE__,
            },
        }
    );
    my $item = $ingredient->item;

    my $test = sub ( $value1, $offset1, $delta, $value2, $offset2 ) {
        local $Test::Builder::Level = $Test::Builder::Level + 1;

        $ingredient->update( { value => $value1 } );
        $item->update( { value => $value1, offset => $offset1 } );
        $t->post_json(
            'https://localhost/project/1/Test-Project/dish/1/ingredients/update',
            {
                ingredient => {
                    id           => $ingredient->id,
                    value        => $value1 + $delta,                 # the only change
                    current_unit => { id => $ingredient->unit_id },
                    comment      => $ingredient->comment,
                }
            }
        );
        $ingredient->discard_changes();
        $item->discard_changes();
        is $item => object {
            call value  => number $value2;
            call offset => number $offset2;
        }
    };

    # value/offset => delta => value/offset
    $test->( 12, -2 => -3 => 9,  +0 );
    $test->( 12, -2 => -2 => 10, +0 );
    $test->( 12, -2 => -1 => 11, -1 );
    $test->( 12, -2 => +0 => 12, -2 );
    $test->( 12, -2 => +1 => 13, +0 );
    $test->( 12, -2 => +2 => 14, +0 );
    $test->( 12, -2 => +3 => 15, +0 );

    $test->( 10, +0 => -1 => 9,  +0 );
    $test->( 10, +0 => +0 => 10, +0 );
    $test->( 10, +0 => +1 => 11, +0 );

    $test->( 8, +2 => -3 => 5,  +0 );
    $test->( 8, +2 => -2 => 6,  +0 );
    $test->( 8, +2 => -1 => 7,  +0 );
    $test->( 8, +2 => +0 => 8,  +2 );
    $test->( 8, +2 => +1 => 9,  +1 );
    $test->( 8, +2 => +2 => 10, +0 );
    $test->( 8, +2 => +3 => 11, +0 );
};

subtest add_ingredient => sub {
    subtest "based on ID" => txn_do_and_rollback $t->schema => sub {
        $ingredients->delete();

        my %properties = (
            article => { id => 1 },
            unit    => { id => 2 },
            comment => 'foobar',
        );

        ok $t->post_json(
            'https://localhost/project/1/Test-Project/dish/1/ingredients/create',
            { ingredient => { %properties, value => __LINE__ } }
          ),
          "POST with existing article ID and existing unit ID";
        $t->status_is(200);

        ok $t->post_json(
            'https://localhost/project/1/Test-Project/dish/1/ingredients/create',
            { ingredient => { %properties, article => { id => 999 }, value => __LINE__ } }
          ),
          "POST with inexistent article ID";
        $t->status_is(400);

        ok $t->post_json(
            'https://localhost/project/1/Test-Project/dish/1/ingredients/create',
            { ingredient => { %properties, unit => { id => 999 }, value => __LINE__ } }
          ),
          "POST with inexistent unit ID";
        $t->status_is(400);

        ok $t->post_json(
            'https://localhost/project/1/Test-Project/dish/1/ingredients/create',
            { ingredient => { %properties, value => __LINE__ } }
          ),
          "POST same data again works";    # test against false positives for 400 above
        $t->status_is(200);

        is [ $t->schema->resultset('DishIngredient')->hri->all ] => array {
            item hash {
                field article_id => 1;
                field unit_id    => 2;
                field item_id    => T();
                etc();
            };
            item hash {
                field article_id => 1;
                field unit_id    => 2;
                field item_id    => T();
                etc();
            };
            end();
        };
    };

    subtest "based on name" => txn_do_and_rollback $t->schema => sub {
        $ingredients->delete();

        my %properties = (
            article => { name => 'foo' },
            unit    => { name => 'bar' },
            comment => 'baz',
        );

        ok $t->post_json(
            'https://localhost/project/1/Test-Project/dish/1/ingredients/create',
            { ingredient => { %properties, value => __LINE__ } }
          ),
          "POST with new article name and new unit name";
        $t->status_is(200);

        ok $t->post_json(
            'https://localhost/project/1/Test-Project/dish/1/ingredients/create',
            { ingredient => { %properties, value => __LINE__ } }
          ),
          "POST with same article name and same unit name";
        $t->status_is(200);

        is [ $t->schema->resultset('DishIngredient')->all ] => array {
            item object {
                call article => object { call name       => 'foo' };
                call unit    => object { call short_name => 'bar' };
                call item_id => T();
            };
            item object {
                call article => object { call name       => 'foo' };
                call unit    => object { call short_name => 'bar' };
                call item_id => T();
            };
            end();
        };
    };
};
