use Coocook::Base;
use Test2::V0;

use Coocook::Schema;

use lib 't/lib/';
use TestDB qw(install_ok upgrade_ok);

sub _schema_eq;    # declare name, implementation is below

# first upgrade scripts created columns in different order
# or had other subtle differences to a fresh deployment
#
# share/ddl/SQLite/upgrade/12-13/fix-cascade.sql is the
# first upgrade script that has an equal result
#
# earlier upgrade scripts MUST NOT be fixed because
# deployments from these versions stay the same and
# will be fixed with upgrade to version 13. Luckily
# we are pretty sure there are no installations
# older than version 13.
my %SCHEMA_VERSIONS_WITH_DIFFERENCES = map { $_ => 1 } ( 3 .. 5, 7 .. 12 );

plan tests => 2 + ( $Coocook::Schema::VERSION - 1 ) + 4;

my $schema_from_code = TestDB->new();
my $schema_from_deploy;
my $schema_from_upgrades = TestDB->new( deploy => 0 );

install_ok $schema_from_upgrades, 1;

ok TestDB->execute_test_data( $schema_from_upgrades, 't/test_data_v1_install.sql' ),
  "populate test data for schema version 1";

for my $version ( 2 .. $Coocook::Schema::VERSION ) {
    subtest "schema version $version" => sub {
        if ( -f ( my $sql_file = "t/test_data_v${version}_upgrade.sql" ) ) {
            ok
              TestDB->execute_test_data( $schema_from_upgrades, $sql_file ),
              "populate additional test data for schema version $version";
        }

        $schema_from_deploy = TestDB->new( deploy => 0 );
        install_ok $schema_from_deploy, $version;

        {    # assert all tables are populated #286
            my $dbh = $schema_from_upgrades->storage->dbh;
            my $sth = $dbh->table_info( undef, undef, undef, 'TABLE' );

            while ( my $table = $sth->fetchrow_hashref ) {
                my $name = $table->{TABLE_NAME};
                my ($count) = $dbh->selectrow_array("SELECT COUNT(*) FROM $name");
                $count > 0 or die "missing any test data in table $name";
            }
        }

        upgrade_ok $schema_from_upgrades, $version;

      SKIP: {
            $SCHEMA_VERSIONS_WITH_DIFFERENCES{$version}
              and skip "Upgrade SQL files are known to be broken", 1;

            _schema_eq
              $schema_from_upgrades => $schema_from_deploy,
              "schema from upgrade SQLs equals schema from deploy SQL";
        }
    };
}

_schema_eq
  $schema_from_deploy => $schema_from_code,
  "schema from deploy SQL and schema from Coocook::Schema code are equal";

_schema_eq
  $schema_from_upgrades => $schema_from_code,
  "schema from upgrade SQLs and schema from Coocook::Schema code are equal";

{
    my $unit_conversions = $schema_from_upgrades->resultset('UnitConversion')
      ->search( undef, { columns => [qw( unit1_id factor unit2_id )] } );

    is [ $unit_conversions->hri->all ] => [
        { unit1_id => 1, factor => 0.001, unit2_id => 2 },    # g to kg
        { unit1_id => 2, factor => 0.001, unit2_id => 4 },    # kg to t
      ],
      "unit_conversions created from old quantity data by migration";
}

subtest "issue #266 order of meals/dishes" => sub {
    my $schema = TestDB->new( deploy => 0 );
    install_ok $schema, 24;
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
    upgrade_ok $schema, 25;
    is [
        $schema->resultset('Meal')->search( undef, { order_by => 'position' } )->get_column('name')->all ]
      => [qw( a b c )],
      "alphabetical order of meals";

    is [
        $schema->resultset('Dish')->search( undef, { order_by => 'position' } )->get_column('name')->all ]
      => [qw( b c a )],
      "dishes in order of insertion into database";
};

sub _schema_eq ( $schema1, $schema2, $test_name ) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $a = { id => 1, dbh => $schema1->storage->dbh };
    my $b = { id => 2, dbh => $schema2->storage->dbh };

    my %table_names;    # union of table names in schema A and B

    for my $schema ( $a, $b ) {
        my $sth = $schema->{dbh}->table_info( undef, undef, undef, 'TABLE' );

        while ( my $table = $sth->fetchrow_hashref ) {
            my $type = $table->{TABLE_TYPE};
            my $name = $table->{TABLE_NAME};
            my $sql  = $table->{sqlite_sql};

            next if $name eq 'dbix_class_deploymenthandler_versions';

            $sql =~ s/\s+/ /gs;    # ignore whitespace differences
            $sql =~ s/['"]//g;     # ignore quote characters

            $schema->{tables}{$name} = $sql;

            $table_names{$name}++;
        }
    }

    is $a->{tables} => $b->{tables}, $test_name;
}
