package Coocook::Model::Organizations;

use Moose;
use experimental qw(signatures);
use feature 'fc';    # Perl v5.16

use Carp;

extends 'Catalyst::Model';

has schema => (
    is  => 'rw',
    isa => 'Coocook::Schema',
);

__PACKAGE__->meta->make_immutable;

# TODO this is called once per request. can we get $schema once for all?
sub ACCEPT_CONTEXT ( $self, $c, @args ) {
    $self->schema( $c->model('DB')->schema );

    return $self;
}

sub create ( $self, %args ) {
    my $name_fc = fc $args{name};

    $args{display_name}   //= $args{name};
    $args{description_md} //= '';

    my $organizations = $self->schema->resultset('Organization');
    my $users         = $self->schema->resultset('User');

    return $self->schema->txn_do(
        sub {
            for my $rs ( $organizations, $users ) {
                $rs->results_exist( { name_fc => $name_fc } )
                  and croak "Name is not available";
            }

            my $organization = $organizations->create( \%args );

            $organization->add_to_organizations_users( { role => 'owner', user_id => $args{owner_id} } );

            return $organization;
        }
    );
}

sub find_by_name ( $self, $name ) {
    return $self->schema->resultset('Organization')->find( { name_fc => fc $name } );
}

=head2 name_available("name")

Returns a boolean value indicating whether the given name
is not used for users/organizations and not blacklisted.

=cut

# proxied to Result::User because of shared namespace
sub name_available ( $self, @args ) { $self->schema->resultset('User')->name_available(@args) }

1;
