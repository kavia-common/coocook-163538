use Coocook::Base;
use Test2::V0;

use Coocook;
use Coocook::Script::Dbck;
use Test::Output;

use lib 't/lib/';
use TestDB;
use Test::Coocook;    # makes Coocook::Script::Dbck not read real config files

plan(19);

my $db = TestDB->new();

ok my $app = Coocook::Script::Dbck->new_with_options();

$app->_schema($db);

ok no_warnings { $app->run }, "no warnings with test data";

{
    $db->txn_begin;

    $db->storage->dbh_do( sub ( $storage, $dbh ) { $dbh->do(<<~SQL) } );
    ALTER TABLE projects ADD COLUMN foobar integer
    SQL

    like warnings { $app->run } => [
        qr/table \W?projects\W?/,    #perldoc
        qr/<<</,
        qr/CREATE TABLE/,
        qr/---/,
        qr/CREATE TABLE/,
        qr/>>>/,
      ],
      "Error about table schema";

    $db->txn_rollback;
}

{
    $db->txn_begin;

    $db->resultset('Article')->find(1)->update( { project_id => 2 } );

    is join( '', @{ warnings sub { $app->run } } ) => <<~EOT, "Inconsistent project_id";
    Project IDs differ for Article row (id = 1): me.project = 2, shop_section.project = 1
    Project IDs differ for ArticleTag row (article_id = 1, tag_id = 1): article.project = 2, tag.project = 1
    Project IDs differ for ArticleUnit row (article_id = 1, unit_id = 1): article.project = 2, unit.project = 1
    Project IDs differ for ArticleUnit row (article_id = 1, unit_id = 2): article.project = 2, unit.project = 1
    Project IDs differ for DishIngredient row (id = 1): meal.project = 1, article.project = 2, unit.project = 1
    Project IDs differ for DishIngredient row (id = 4): meal.project = 1, article.project = 2, unit.project = 1
    Project IDs differ for DishIngredient row (id = 7): meal.project = 1, article.project = 2, unit.project = 1
    Project IDs differ for DishIngredient row (id = 11): meal.project = 1, article.project = 2, unit.project = 1
    Project IDs differ for Item row (id = 1): purchase_list.project = 1, unit.project = 1, article.project = 2
    Project IDs differ for RecipeIngredient row (id = 2): recipe.project = 1, article.project = 2, unit.project = 1
    EOT

    $db->txn_rollback;
}

my $cols = do { no warnings 'once'; $Coocook::Script::Dbck::SQLITE_NOTORIOUS_EMPTY_STRING_COLUMNS }
  || die;

for my $rs ( sort keys %$cols ) {
    my @cols = map { ref ? @$_ : $_ } $cols->{$rs};

    for my $col (@cols) {
        my $table = $db->resultset($rs)->result_source->name();

        $db->txn_begin;

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

        $db->txn_rollback;

        if ( $col eq 'value' ) {
            $db->txn_begin;

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

            $db->txn_rollback;
        }
    }
}

for my $table (qw< Organization User >) {
    $db->txn_begin;

    $db->resultset($table)->one_row->update( { name_fc => 'foobar' } );

    like warning { $app->run } => qr/Incorrect name_fc for $table/i, "incorrect name_fc in $table";

    $db->txn_rollback;
}

for my $col (qw< url_name url_name_fc >) {
    $db->txn_begin;

    $db->resultset('Project')->one_row->update( { $col => 'foobar' } );

    like warning { $app->run } => qr/Incorrect $col for project/, "incorrect $col in projects";

    $db->txn_rollback;
}

{
    $db->txn_begin;

    $db->resultset('UnitConversion')->one_row->reverse()->update();

    like warning { $app->run } => qr/unit1_id.+unit2_id/,
      "unit_conversions: unit1_id must be lower than unit2_id (relationship normalization)";

    $db->txn_rollback;
}
