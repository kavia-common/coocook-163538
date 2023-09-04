use Test2::V0;
use experimental qw(signatures);

use Test2::Require::Module 'Test::PostgreSQL';
use Test2::Require::Module 'DateTime::Format::Pg';

use Coocook::Script::Deploy;
use Coocook::Schema;
use Data::Dumper;
use DBI;
use DBIx::Diff::Schema qw(diff_db_schema);
use Test::Builder;

use lib 't/lib';
use TestDB qw(install_ok upgrade_ok);
use Test::Coocook;

my $FIRST_PGSQL_SCHEMA_VERSION = 21;

plan tests => 3 + ( $Coocook::Schema::VERSION - $FIRST_PGSQL_SCHEMA_VERSION ) + 9;

my $psql = Test::PostgreSQL->new();
my $dbh  = DBI->connect( $psql->dsn );

$dbh->do('CREATE DATABASE dbic');
my $schema_from_dbic = Coocook::Schema->connect( $psql->dsn( dbname => 'dbic' ) );
ok lives { $schema_from_dbic->deploy() }, "deploy with DBIx::Class";

my $schema_from_deploy;    # initialized in loop

$dbh->do('CREATE DATABASE upgrades');
my $schema_from_upgrades = Coocook::Schema->connect( $psql->dsn( dbname => 'upgrades' ) );
install_ok( $schema_from_upgrades, $FIRST_PGSQL_SCHEMA_VERSION );

ok(
    TestDB->execute_test_data(
        $schema_from_upgrades, "t/test_data_v${FIRST_PGSQL_SCHEMA_VERSION}_install.sql"
    ),
    "populate test data"
);

for my $version ( $FIRST_PGSQL_SCHEMA_VERSION + 1 .. $Coocook::Schema::VERSION ) {
    subtest "schema version $version" => sub {
        my $database = 'deploy' . $version;
        $dbh->do("CREATE DATABASE $database");
        $schema_from_deploy = Coocook::Schema->connect( $psql->dsn( dbname => $database ) );
        install_ok( $schema_from_deploy, $version );

        if ( -f ( my $sql_file = "t/test_data_v${version}_upgrade.sql" ) ) {
            ok(
                TestDB->execute_test_data( $schema_from_upgrades, $sql_file ),
                "populate additional test data for schema version $version"
            );
        }

        upgrade_ok( $schema_from_upgrades, $version );

        schema_diff_like( $schema_from_upgrades, $schema_from_deploy, {},
            "schema from upgrade SQLs equals schema from deploy SQL" );
    };
}

{
    my $unit_conversions = $schema_from_upgrades->resultset('UnitConversion')
      ->search( undef, { columns => [qw( unit1_id factor unit2_id )] } );

    is [ $unit_conversions->hri->all ] => [
        { unit1_id => 1, factor => 0.001, unit2_id => 2 },    # g to kg
        { unit1_id => 2, factor => 0.001, unit2_id => 4 },    # kg to t
      ],
      "unit_conversions created from old quantity data by migration";
}

note "Deleting original test data ...";
$schema_from_upgrades->resultset($_)->delete() for qw(
  DishIngredient
  RecipeIngredient
  Item
  ArticleUnit
  Dish
  Meal
  Project
  Organization
  User
  BlacklistEmail
  BlacklistUsername
  FAQ
  Terms
);

# share/test_data.sql matches only current schema -> can only after upgrades
ok( TestDB->execute_test_data($schema_from_dbic),     "Execute test data in DB from DBIx::Class" );
ok( TestDB->execute_test_data($schema_from_deploy),   "Execute test data in DB from deploy SQL" );
ok( TestDB->execute_test_data($schema_from_upgrades), "Execute test data in DB from upgrade SQLs" );

note "Fixing Pgsql sequences after bulk insert";
for my $source ( $schema_from_dbic->sources ) {
    $source eq 'Session'    # this table has string id column
      and next;

    my $result_source = $schema_from_dbic->resultset($source)->result_source;

    if ( $result_source->has_column('id') ) {
        my $table = $result_source->name;

        $schema_from_dbic->storage->dbh_do( sub ( $storage, $dbh ) { $dbh->do(<<~SQL) } );
        SELECT setval('${table}_id_seq', (SELECT MAX(id) FROM $table), true)
        SQL
    }
}

subtest "boolean values" => sub {
    my $row = $schema_from_dbic->resultset('Project')->one_row;
    my $col = 'is_public';

    like $row->get_column($col) => qr/^[01]$/, "DBD::Pg returns 0 or 1";

    ok $row->update( { $col => $_ } ), "SET $col = $_" for 0, 1;
    ok $row->update( { $col => '' } ), "SET $col = ''";
};

subtest "deleting projects" => sub {
    my $t = Test::Coocook->new( schema => $schema_from_dbic );
    $t->get_ok('/');
    $t->login_ok( 'john_doe', 'P@ssw0rd' );
    $t->get_ok('https://localhost/project/1/Test-Project/settings');

    $t->submit_form_ok( { form_name => 'delete', with_fields => { confirmation => 'Test Project' } },
        "delete project" );

    is $schema_from_dbic->resultset('Project')->find(1) => undef, "project has vanished";
};

# rename Pgsql schema to match SQLite schema name 'main'
$schema_from_deploy->storage->dbh_do( sub ( $storage, $dbh ) { $dbh->do(<<SQL) } );
ALTER SCHEMA public RENAME TO main
SQL

my $sqlite_schema = TestDB->new();

SKIP: {
    # https://metacpan.org/release/ISHIGAKI/DBD-SQLite-1.72/source/Changes#L14
    $DBD::SQLite::VERSION < 1.71
      or skip "DBD::SQLite broke compatibility with 1.71_05";

    schema_diff_like(
        $schema_from_deploy,
        $sqlite_schema,
        hash {
            field deleted_tables => [
                'main.dbix_class_deploymenthandler_versions',    # not created by DBIC
            ];
            field modified_tables => hash {
                my $lc2uc_id = { id => { old_type => 'integer', new_type => 'INTEGER' } };

                # SQLite PKs are deployed with uppercase 'id INTEGER PRIMARY KEY'
                field 'main.' . $_ => { modified_columns => $lc2uc_id } for qw<
                  articles
                  blacklist_emails
                  blacklist_usernames
                  organizations
                  projects
                  purchase_lists
                  recipes_of_the_day
                  recipes
                  shop_sections
                  tag_groups
                  tags
                  terms
                  units
                  unit_conversions
                  users
                >;

                # https://github.com/perlancar/perl-DBIx-Diff-Schema/issues/1
                field 'main.items' => {
                    added_columns    => ['offset'],
                    deleted_columns  => ['"offset"'],
                    modified_columns => $lc2uc_id,
                };
                field 'main.'
                  . $_ => {
                    added_columns    => ['position'],
                    deleted_columns  => ['"position"'],
                    modified_columns => $lc2uc_id,
                  }
                  for qw<
                  dish_ingredients
                  faqs
                  recipe_ingredients
                  meals
                  dishes
                  >;
            };
        }
    );
}

# most important finding: CURRENT_TIMESTAMP is UTC in SQLite but local timezone in PostgreSQL
subtest "timestamps are stored in UTC" => sub {
    my $schema = $schema_from_dbic;

    # with Test::PostgreSQL the default timezone is UTC which makes bugs unnoticeable
    $schema->storage->dbh_do( sub ( $storage, $dbh ) { $dbh->do(<<~SQL) } );
    SET TIME ZONE 'Pacific/Chatham' -- weird timezone UTC+12:45
    SQL

    my $t = Test::Coocook->new(
        config => { enable_user_registration => 1 },
        schema => $schema,
    );

    $t->get_ok('/');
    $t->register_ok( { username => 'u', email => 'u@example.com', password => 'p', password2 => 'p' } );
    $t->email_count_is(2);
    $t->get_ok_email_link_like(qr/verify/);
    $t->clear_emails();
    $t->submit_form_ok( { with_fields => { password => 'p' } } );

    my $utc_hour  = sprintf '%02i', (gmtime)[2];    # gmtime() provides UTC and calls it "GMT"
    my $utc_regex = qr/ $utc_hour:..:../;

    my $user = $schema->resultset('User')->find( { name_fc => 'u' } );
    like $user->get_column('email_verified') => $utc_regex, "column 'email_verified' is in UTC";

    $t->request_recovery_link_ok('u@example.com');
    $user->discard_changes();
    like( $user->get_column($_) => $utc_regex, "column '$_' is in UTC" )
      for qw< token_created token_expires >;

    ok $user->update( { map { $_ => undef } qw< token_created token_expires > } ),
      "set columns NULL to avoid false positives";

    $t->follow_link_ok( { text        => 'Settings' } );
    $t->submit_form_ok( { with_fields => { new_email => 'x@example.com' } } );
    $user->discard_changes();
    like( $user->get_column($_) => $utc_regex, "column '$_' is in UTC" )
      for qw< token_created token_expires >;

    $t->get_ok('/');
    $t->submit_form_ok( { with_fields => { name => 'Project UTC' } }, "create project" );
    $t->follow_link_ok( { text        => 'Project' } );
    $t->follow_link_ok( { text        => 'Settings', class_regex => qr/^ .* nav-link .* $/x } );
    $t->submit_form_ok( { with_fields => { archive => 'on' } } );
    my $project = $schema->resultset('Project')->find( { name => 'Project UTC' } ) || die;
    like( $project->get_column($_) => $utc_regex, "column '$_' is in UTC" ) for qw< created archived >;
};

subtest "issue #266 order of meals/dishes" => sub {
    $dbh->do('CREATE DATABASE issue266');
    my $schema = Coocook::Schema->connect( $psql->dsn( dbname => 'issue266' ) );
    install_ok( $schema, 24 );

    my $user = $schema->resultset('User')
      ->create( { name => '', password_hash => '', display_name => '', email_fc => '' } );

    my $project = $user->create_related( owned_projects => { name => '', description => '' } );

    $schema->storage->dbh_do(
        sub ( $storage, $dbh ) {
            $dbh->do(<<~SQL) for qw( b c a );    # irregular order
            INSERT INTO meals (project_id,date,name,comment) VALUES (1,'2000-01-01', '$_','')
            SQL

            $dbh->do(<<~SQL) for qw( b c a );    # irregular order
            INSERT INTO dishes (meal_id,servings,preparation,description,name,comment) VALUES (1,42,'','', '$_','')
            SQL
        }
    );
    upgrade_ok( $schema, 25 );
    is [
        $schema->resultset('Meal')->search( undef, { order_by => 'position' } )->get_column('name')->all ]
      => [qw( a b c )],
      "alphabetical order of meals";

    is [
        $schema->resultset('Dish')->search( undef, { order_by => 'position' } )->get_column('name')->all ]
      => [qw( b c a )],
      "dishes in order of insertion into database";
};

# explicitly destroy DBIC objects before Pg.
# otherwise order of destruction is random
# and DBIC might throw errors if Pg is already dead
for my $schema ( $schema_from_dbic, $schema_from_deploy, $schema_from_upgrades ) {
    $schema->storage->dbh->disconnect();
}

sub schema_diff_like ( $schema1, $schema2, $expected_diff, $name = undef ) {

    # TODO doesn't detect constraint changes, e.g. missing UNIQUEs
    my $diff = diff_db_schema( map { $_->storage->dbh } $schema1, $schema2 );

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    is
      $diff => $expected_diff,
      $name // "database schemas equal"
      or diag Dumper($diff);
}
