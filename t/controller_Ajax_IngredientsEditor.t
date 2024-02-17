use Test2::V0;

use lib 't/lib';
use TestDB qw(txn_do_and_rollback);
use Test::Coocook;

plan(6);

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
$ingredients->delete();

subtest add_ingredient => sub {
    subtest "based on ID" => txn_do_and_rollback $t->schema => sub {
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
