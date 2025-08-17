use Coocook::Base;

use Coocook::Script::Dbck;
use Test2::V0 -no_warnings => 1;

use lib 't/lib/';
use TestDB qw(txn_do_and_rollback);
use Test::Coocook;    # makes Coocook::Script::Dbck not read real config files

plan(26);

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

    is warnings { $app->run } => [ split /\n\K/, <<~EOT ], "Inconsistent project_id";
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

txn_do_and_rollback $db, sub {
    $db->resultset('DishIngredient')->find(1)->update( { article_id => 2 } );

    like warnings { $app->run } => [qr/article_id/],
      "Inconstitent article_id for dish ingredient/purchase list item";
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

            like warnings { $app->run } => [qr/column \W?$col\W? .+ empty string ''/],
              "$col of '' in $rs";
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

            like warnings { $app->run } => [qr/($rs|$table) .+ number.format .+ '0,1'/x],
              "invalid number format '0,1' in $rs";
        };
    }
}

for my $table (qw< Organization User >) {
    subtest "incorrect name_fc in $table" => txn_do_and_rollback $db => sub {
        $db->resultset($table)->one_row->update( { name_fc => 'foobar' } );

        like warning { $app->run } => qr/Incorrect name_fc for $table/i, "default";

        $app->fix(1);
        like warnings { $app->run } => array {
            item qr/Incorrect name_fc for $table/i;
            item "... Fixed!\n";
            end();
        },
          "with --fix";
        $app->fix('');    # reset to default

        ok no_warnings { $app->run }, "actually fixed";
    };
}

for my $col (qw< url_name url_name_fc >) {
    subtest $col => txn_do_and_rollback $db => sub {
        my $project        = $db->resultset('Project')->one_row;
        my $original_value = $project->get_column($col);
        $project->update( { $col => 'foobar' } );

        like warning { $app->run } => qr/Incorrect $col for project/, "incorrect $col in projects";
        $project->discard_changes();
        is $project->get_column($col) => 'foobar', "... $col not changed";

        $col eq 'url_name_fc'    # --fix feature not required for column
          and return;            # that will be pretty much obsolete after #320

        $app->fix(1);
        like warnings { $app->run } => array {
            item qr/Incorrect $col for project/;
            item "... Fixed!\n";
            end();
        };
        $project->discard_changes();
        is $project->get_column($col) => $original_value, "$col fixed";

        $app->fix('');           # reset to default
    };
}

subtest "normalization of unit conversions" => txn_do_and_rollback $db => sub {
    my $row = $db->resultset('UnitConversion')->one_row;
    $row->reverse()->update();

    like warning { $app->run } => qr/ unit1_id .+ unit2_id /x,
      "unit_conversions: unit1_id must be lower than unit2_id (relationship normalization)";

    $row->discard_changes();
    cmp_ok $row->unit1_id, '>', $row->unit2_id, "... still not normalized";

    $app->fix(1);
    like warnings { $app->run } => array {
        item qr/ unit1_id .+ unit2_id /x;
        item "... Fixed!\n";
        end();
    },
      "with --fix";
    $row->discard_changes();
    cmp_ok $row->unit1_id, '<', $row->unit2_id, "... now normalized";
    $app->fix('');    # reset to default
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

    my $sql = <<~SQL;    # some useful SQL query showing unassigned dish ingredients
    SELECT
        dish_ingredients.id,
        meals.date || ' ' || meals.name AS meal,
        dishes.name AS dish,
        value || ' ' || units.long_name AS amount,
        articles.name AS article,
        dish_ingredients.comment
    FROM dish_ingredients
    JOIN articles ON articles.id = article_id
    JOIN units ON units.id = unit_id
    JOIN dishes ON dishes.id = dish_id
    JOIN meals ON meals.id = meal_id
    WHERE dish_ingredients.item_id IS NULL
        AND EXISTS(
            SELECT 1
            FROM purchase_lists
            WHERE purchase_lists.project_id = meals.project_id
        );
    SQL
    is $db->storage->dbh_do( sub ( $storage, $dbh ) { $dbh->selectall_arrayref($sql) } ) => [],
      "SQL query returns empty";

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
    is $db->storage->dbh_do( sub ( $storage, $dbh ) { $dbh->selectall_arrayref($sql) } ) =>
      array { item T(); etc() },
      "SQL query with relevant data";

    note "Deleting all purchase lists ...";
    $db->resultset('Project')->update( { default_purchase_list_id => undef } );
    $db->resultset('PurchaseList')->delete();
    $db->resultset('DishIngredient')->results_exist or die "this shouldn't be deleted";

    ok !warns { $app->run }, "doesn't warn";
};

subtest "items without dish ingredients", txn_do_and_rollback $db, sub {
    my ( $item1, $item2 ) = $db->resultset('Item')->all;
    $item1->ingredients->delete();
    like warnings { $app->run } => [qr/dish ingredients .+zero/];

    $item1->update( { value => 0 } );
    unlike warning { $app->run } => qr/zero/;
};

subtest "ingredients with value != sum of ingredients", txn_do_and_rollback $db, sub {
    my $sql = <<~SQL;    # some useful SQL query showing items with their dish ingredients
    SELECT
        items.id,
        articles.name,
        items.value || units.short_name AS "item amount",
        (
            SELECT GROUP_CONCAT(value || units.short_name, ' + ')
            FROM dish_ingredients
            JOIN units ON units.id = unit_id
            WHERE item_id = items.id
        ) AS "ingredient amounts"
        FROM items
        JOIN articles ON articles.id = article_id
        JOIN units ON units.id = unit_id
    SQL
    ok $db->storage->dbh_do( sub ( $storage, $dbh ) { $dbh->do($sql) } ), "SQL query executes";

    my $dish_ingredient = $db->resultset('DishIngredient')->find(1);
    my $original_item   = $dish_ingredient->item;

    $dish_ingredient->unit_id != $original_item->unit_id
      or die "test broken";

    ( $original_item->value == 14.5 and $original_item->offset == 0 )
      or die "test broken";

    $dish_ingredient->update( { value => 1000 } );
    my $item_id = $dish_ingredient->item_id;
    like warnings { $app->run } => [qr/^Item $item_id: .+ != .+ \(.*1000\w+.*\)$/];

    $app->fix(1);
    like warnings { $app->run } => array {
        item qr/1000/;
        item "... Fixed!\n";
        end();
    },
      "with --fix";

    my $item = $original_item->self_rs->one_row;
    is $item->value  =>  15,  "value";
    is $item->offset => -0.5, "offset";
    is $item->total  => $original_item->total, "total didn't change";
};
