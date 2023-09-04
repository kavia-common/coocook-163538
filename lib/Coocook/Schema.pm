package Coocook::Schema;

# ABSTRACT: DBIx::Class-based SQL database representation

use Moose;
use experimental qw(signatures);
use namespace::autoclean;

use Carp;
use Clone;    # indirect dependency required for connection()
use DateTime;
use DBIx::Class::Helpers::Util qw< normalize_connect_info >;
use Scope::Guard               qw(guard);

our $VERSION = 27;    # version of schema definition, not software version!

extends 'DBIx::Class::Schema::Config';

__PACKAGE__->load_components(
    qw<
      Helper::Schema::QuoteNames
    >
);

__PACKAGE__->meta->make_immutable;

__PACKAGE__->load_namespaces( default_resultset_class => '+Coocook::Schema::ResultSet' );

=head1 Generic Methods

=head2 connection

Overrides original C<connection> in order to set sane default values.

=over 4

=item * enable C<foreign_keys> pragma in SQLite

=back

=cut

# DBIx::Class uses Hash::Merge for merging our $connect_info with other data.
# That module uses Clone::Choose but only with Clone.pm it can do the merge.
# So we need to require Clone.pm
sub connection {
    my $self = shift;

    my $connect_info  = normalize_connect_info(@_);
    my $on_connect_do = \$connect_info->{on_connect_do};

    # identifying the sql_type at connect time is easier than parsing the DSN
    my $enable_fk = sub ($storage) {
        $storage->sqlt_type eq 'SQLite'
          and return ['PRAGMA foreign_keys = 1'];

        return;    # required because otherwise returns result '' from 'eq' above
    };

    if ( not defined $$on_connect_do ) {
        $$on_connect_do = [$enable_fk];
    }
    elsif ( ref $$on_connect_do eq 'ARRAY' ) {
        unshift @$$on_connect_do, $enable_fk;
    }
    elsif ( ref $$on_connect_do eq 'CODE' ) {
        my $coderef = $$on_connect_do;    # copy original value
        $$on_connect_do = [
            $enable_fk,                   # $enable_fk first to allow overriding
            sub {
                $coderef->();             # return value of original simple coderef is to be ignored
                return [];
            }
        ];
    }
    else {    # scalar
        my $scalar = $$on_connect_do;    # copy original value
        $$on_connect_do = [
            $enable_fk,                  # $enable_fk first to allow overriding
            sub { [$scalar] }
        ];
    }

    return $self->next::method($connect_info);
}

=head2 count(@resultsets?)

Returns accumulated number of rows in @resultsets. Defaults to all resultsets.

=cut

sub count ( $self, @sources ) {
    my $records = 0;
    $records += $self->resultset($_)->count for @sources ? @sources : $self->sources;
    return $records;
}

sub statistics ($self) {
    return {
        dishes_served   => $self->resultset('Dish')->in_past_or_today->sum_servings,
        dishes_planned  => $self->resultset('Dish')->in_future->sum_servings,
        recipes         => $self->resultset('Recipe')->count_distinct('name'),
        public_projects => $self->resultset('Project')->public->count,
        users           => $self->resultset('User')->count,
        organizations   => $self->resultset('Organization')->count,
    };
}

=head1 PostgreSQL-specific Methods

=head2 pgsql_set_constraints_deferred()

Issues `SET CONSTRAINTS ALL DEFERRED` if connected to PostgreSQL.
Otherwise does nothing.

=cut

sub pgsql_set_constraints_deferred ($self) {
    if ( $self->storage->sqlt_type eq 'PostgreSQL' ) {
        $self->storage->dbh_do( sub ( $storage, $dbh ) { $dbh->do('SET CONSTRAINTS ALL DEFERRED') } );
    }
}

=head1 SQLite-specific Methods

=head2 $schema->fk_checks_off_do( sub { ... }, @args )

Runs given coderef with SQLite pragma C<foreign_keys> temporarily turned off.
The original pragma state is then restored.

In case of success the coderef's return value is passed if it is true.
In other cases the return value is undefined.

Probably we should enforce an FK integrity check after the
completion of the (possibly long) subroutine as soon as we
know how to do this.

=cut

sub fk_checks_off_do ( $self, $coderef, @args ) {
    my $original_state = $self->sqlite_pragma('foreign_keys');

    $original_state
      and $self->disable_fk_checks();

    my $result = $coderef->(@args);

    $original_state
      and $self->enable_fk_checks();

    my $error = $self->storage->dbh_do( sub { $_[1]->selectrow_array('PRAGMA foreign_key_check') } );

    if ($error) {
        croak "FOREIGN KEY constraint failed after block inside fk_checks_off_do()";
    }

    return $result;
}

=head2 fk_checks_off_guard()

Returns a L<Scope::Guard> object that temporarily disables FOREIGN KEY checks
and resets the original state when it goes out of scope.

=cut

sub fk_checks_off_guard ($self) {
    my $original_state = $self->sqlite_pragma('foreign_keys');

    $self->disable_fk_checks();

    return guard { $original_state and $self->enable_fk_checks() };
}

sub enable_fk_checks  ($self) { $self->sqlite_pragma( foreign_keys => 1 ) }
sub disable_fk_checks ($self) { $self->sqlite_pragma( foreign_keys => 0 ) }

sub sqlite_pragma ( $self, $pragma, $set_value = undef ) {
    my $storage = $self->storage;

    $storage->sqlt_type eq 'SQLite'
      or croak "sqlite_pragma() works only on SQLite";

    my $sql = "PRAGMA '$pragma'";

    defined $set_value
      and $sql .= " = '$set_value'";

    $storage->debug
      and $storage->debugfh->print("$sql\n");

    return $storage->dbh_do(
        sub ( $storage, $dbh ) {
            defined $set_value
              ? $dbh->do($sql)
              : $dbh->selectrow_array($sql);
        }
    );
}

1;
