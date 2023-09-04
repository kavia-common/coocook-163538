package Coocook::Schema::ResultSet::ProjectUser;

use Moose;
use experimental qw(signatures);
use namespace::autoclean;

extends 'Coocook::Schema::ResultSet';

__PACKAGE__->meta->make_immutable;

=head2 owners()

Returns a new resultset with records where C<role> is C<owner>.

=cut

sub owners ($self) {
    return $self->search( { $self->me('role') => 'owner' } );
}

1;
