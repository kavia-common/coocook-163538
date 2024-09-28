use Coocook::Base;

use Coocook::Script::Dbck;
use Test2::V0 -no_warnings => 1;

use lib 't/lib/';
use TestDB qw(txn_do_and_rollback);
use Test::Coocook;    # makes Coocook::Script::Dbck not read real config files

plan(25);

my $db = TestDB->new( test_data => 0 );

ok my $app = Coocook::Script::Dbck->new_with_options();

$app->_schema($db);

ok no_warnings { $app->run }, "no warnings with empty database";

TestDB->execute_test_data($db);
ok no_warnings { $app->run }, "no warnings with test data";

txn_do_and_rollback $db, sub {
    $db->storage->dbh_do( sub ( $storage, $dbh ) { $dbh->do(<<~SQL) } );
    ALTER TABLE projects ADD COLUMN foobar integer
    SQL

    like warnings { $app->run } => [
        qr/table \W?projects\W?/,    #perltidy
        qr/<<</,
        qr/CREATE TABLE/,
        qr/---/,
        qr/CREATE TABLE/,
        qr/>>>/,
      ],
      "Error about table schema";
};

txn_do_and_rollback $db, sub {
    $db->resultset('Article')->find(1)->update( { project_id => 2 } );

    is warnings { $app->run } => [ split /\n\K/, <<~EOT], "Inconsistent project_id";
    Project IDs differ for Article row (id = 1): me.project = 2, shop_section.project = 1
    Project IDs differ for ArticleTag row (article_id = 1, tag_id = 1): article.project = 2, tag.project = 1
    Project IDs differ for ArticleUnit row (article_id = 1, unit_id = 1): article.project = 2, unit.project = 1
    Project IDs differ for ArticleUnit row (article_id = 1, unit_id = 2): article.project = 2, unit.project = 1
    Project IDs differ for DishIngredient row (id = 1): meal.project = 1, purchase_list.project = 1, article.project = 2, unit.project = 1
    Project IDs differ for DishIngredient row (id = 4): meal.project = 1, purchase_list.project = 1, article.project = 2, unit.project = 1
    Project IDs differ for DishIngredient row (id = 7): meal.project = 1, purchase_list.project = 1, article.project = 2, unit.project = 1
    Project IDs differ for DishIngredient row (id = 11): meal.project = 1, purchase_list.project = 1, article.project = 2, unit.project = 1
    Project IDs differ for Item row (id = 1): purchase_list.project = 1, unit.project = 1, article.project = 2
    Project IDs differ for RecipeIngredient row (id = 2): recipe.project = 1, article.project = 2, unit.project = 1
    EOT
};

my $cols = do { no warnings 'once'; $Coocook::Script::Dbck::SQLITE_NOTORIOUS_EMPTY_STRING_COLUMNS }
  || die;

for my $rs ( sort keys %$cols ) {
    my @cols = map { ref ? @$_ : $_ } $cols->{$rs};

    for my $col (@cols) {
        my $table = $db->resultset($rs)->result_source->name();

        txn_do_and_rollback $db, sub {

            # set first row's value to empty string ''
            # can't use DBIC update() here because Component::Result::Boolify is too good
            $db->storage->dbh_do( sub ( $storage, $dbh ) { $dbh->do(<<~SQL) } );
            UPDATE $table
            SET $col = ''
            WHERE id = (
                SELECT id
                FROM $table
                LIMIT 1
            )
            SQL

            like warning { $app->run } => qr/column \W?$col\W? .+ empty string ''/, "$col of '' in $rs";
        };

        $col eq 'value' and txn_do_and_rollback $db, sub {

            # set first row's value to German number format '0,1'
            $db->storage->dbh_do( sub ( $storage, $dbh ) { $dbh->do(<<~SQL) } );
            UPDATE $table
            SET value = '0,1'
            WHERE id = (
                SELECT id
                FROM $table
                LIMIT 1
            )
            SQL

            like warning { $app->run } => qr/($rs|$table) .+ number.format .+ '0,1'/x,
              "invalid number format '0,1' in $rs";
        };
    }
}

for my $table (qw< Organization User >) {
    txn_do_and_rollback $db, sub {
        $db->resultset($table)->one_row->update( { name_fc => 'foobar' } );

        like warning { $app->run } => qr/Incorrect name_fc for $table/i, "incorrect name_fc in $table";
    };
}

for my $col (qw< url_name url_name_fc >) {
    txn_do_and_rollback $db, sub {
        $db->resultset('Project')->one_row->update( { $col => 'foobar' } );

        like warning { $app->run } => qr/Incorrect $col for project/, "incorrect $col in projects";
    };
}

txn_do_and_rollback $db, sub {
    $db->resultset('UnitConversion')->one_row->reverse()->update();

    like warning { $app->run } => qr/unit1_id.+unit2_id/,
      "unit_conversions: unit1_id must be lower than unit2_id (relationship normalization)";
};

txn_do_and_rollback $db, sub {
    $db->resultset('PurchaseList')->find(2)->delete();

    my $purchase_list = $db->resultset('PurchaseList')->find(1);
    $purchase_list->items->delete();
    $purchase_list->update( { project_id => 2 } );
    $purchase_list->project->update( { default_purchase_list_id => 1 } );

    like warning { $app->run } => qr/default_purchase_list/,
      "project's default purchase list belongs to other project";
};

subtest "projects with purchase lists but without default_purchase_list",
  txn_do_and_rollback $db => sub {
    my $project = $db->resultset('Project')->find(1);
    $project->update( { default_purchase_list_id => undef } );

    like warning { $app->run } => qr/default[ _]purchase[ _]list/, "warns";

    $project->purchase_lists->delete();

    ok !warns { $app->run }, "doesn't warn without purchase lists";
  };

subtest "project with purchase list but unassigned dish ingredients", txn_do_and_rollback $db, sub {
    ok !warns { $app->run }, "doesn't warn with all ingredients assigned";

    note "Creating another dish ingredient without assigning it ...";
    $db->resultset('DishIngredient')->create(
        {
            dish_id    => 1,
            prepare    => 0,
            article_id => 1,
            value      => 1.0,
            unit_id    => 1,
            comment    => '',
        }
    );

    like warning { $app->run } => qr/unassigned/, "warns";

    note "Deleting all purchase lists ...";
    $db->resultset('Project')->update( { default_purchase_list_id => undef } );
    $db->resultset('PurchaseList')->delete();
    $db->resultset('DishIngredient')->results_exist or die "this shouldn't be deleted";

    ok !warns { $app->run }, "doesn't warn";
};

subtest "items without dish ingredients", txn_do_and_rollback $db, sub {
    my ( $item1, $item2 ) = $db->resultset('Item')->all;
    $item1->ingredients->delete();
    like warning { $app->run } => qr/dish ingredients .+zero/;

    $item1->update( { value => 0 } );
    unlike warning { $app->run } => qr/zero/;
};

subtest "ingredients with value < sum of ingredients", txn_do_and_rollback $db, sub {
    my $dish_ingredient = $db->resultset('DishIngredient')->find(2);
    $dish_ingredient->update( { value => 1000 } );
    like warnings { $app->run } => [qr/value .*(?:lower| \< )/];
};
