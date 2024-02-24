package TestDB;

use Coocook::Base;

use parent 'DBICx::TestDatabase';

use Coocook::Script::Deploy;
use Coocook::DeploymentHandler;
use PerlX::Maybe;
use Sub::Exporter -setup => { exports => [qw(install_ok txn_do_and_rollback upgrade_ok)] };
use Test::Builder;
use Test2::V0 -no_warnings => 1;

=head1 CLASS METHODS

=head2 new(...)

Like L<DBICx::TestDatabase> but can initialize database with C<share/test_data.sql>.

=cut

sub new ( $class, %opts ) {
    my $deploy    = delete $opts{deploy}    // 1;
    my $test_data = delete $opts{test_data} // 1;

    $deploy
      or $opts{nodeploy} = 1;

    my $schema = $class->next::method( 'Coocook::Schema', \%opts );

    ( $deploy and $test_data )
      and $class->execute_test_data($schema);

    return $schema;
}

=head2 execute_test_data( $schema, $filename? )

Executes statements from C<$filename> or C<share/test_data.sql>.
Returns C<$schema> again.

Triggers reset of sequence values if the connection is PostgreSQL.

=cut

# method name not 'insert_' because not all statements are INSERTs
sub execute_test_data ( $class, $schema, $filename = 'share/test_data.sql' ) {
    open my $fh, '<', $filename
      or die $!;

    my $statement = "";

    while ( my $line = <$fh> ) {
        chomp $line;

        # Remove comments from SQL file
        $line =~ s/ -- .* $//x;

        # Remove trailing and leading whitespaces
        $line =~ s/ ^\s+ | \s+$ //xg;

        # Skip empty lines
        length($line) or next;

        # All lines get concatenated to $statement, only when a semicolon is found
        # at the end of a line $statement gets executed and cleared
        length $statement
          and $statement .= ' ';

        $statement .= $line;

        # Only let DBICx::TestDatabase execute the SQL-Statement if it is complete, i.e.
        # there is a semicolon at the end of the line
        if ( $line =~ m/ \; $ /x ) {
            my $storage = $schema->storage;

            $storage->debug
              and $storage->debugfh->print("$statement\n");

            $storage->dbh_do( sub ( $storage, $dbh ) { $dbh->do($statement) } );

            $statement = "";
        }
    }

    close $fh;

    $schema->pgsql_reset_sequence_values();

    return $schema;
}

=head1 PACKAGE FUNCTIONS

=head2 install_ok( $schema, $version?, $name? )

=cut

sub install_ok ( $schema, $version = undef, $name = undef ) {
    my $dh = _build_dh( $schema, $version );

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    ok $dh->install(), $name || "install version " . $dh->to_version;
}

=head2 txn_do_and_rollback( $schema, sub { ... }, @coderef_args? )

Takes a coderef like L<DBIx::Class::Schema/txn_do>
but B<always> does a rollback after running the code.
Useful for unit tests which need to temporarily modify
the database for test cases.

Can be called in void context to execute C<$coderef> immediately
or used in argument list, e.g. for C<subtest()> to get a coderef.

    txn_do_and_rollback $schema, sub {
        ...
    };

    # transaction begun and rolled back inside subtest
    subtest "...", txn_do_and_rollback $schema, sub {
        ...;
    };

=cut

sub txn_do_and_rollback ( $schema, $coderef, @coderef_args ) {
    my $wrapper_coderef = sub {
        $schema->txn_begin();
        my @return = $coderef->(@coderef_args);
        $schema->txn_rollback();
        return @return;
    };

    return defined wantarray
      ? $wrapper_coderef         # any context -> return coderef
      : $wrapper_coderef->();    # void context -> execute now
}

=head2 upgrade_ok( $schema, $version?, $name? )

=cut

sub upgrade_ok ( $schema, $version = undef, $name = undef ) {
    my $dh = _build_dh( $schema, $version );

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    ok $dh->upgrade(), $name || "upgrade to version " . $dh->to_version;
}

sub _build_dh ( $schema, $version = undef ) {
    return Coocook::DeploymentHandler->new(
        {
            schema           => $schema,
            script_directory => 'share/ddl',
            databases        => [ $schema->storage->sqlt_type . "" ],    # stringification like in App::DH
            maybe to_version => $version,
        }
    );
}

1;
