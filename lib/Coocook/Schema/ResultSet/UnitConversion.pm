package Coocook::Schema::ResultSet::UnitConversion;

use Moose;
use experimental qw(signatures);
use namespace::autoclean;

extends 'Coocook::Schema::ResultSet';

__PACKAGE__->meta->make_immutable;

sub transitive     ($self) { $self->search( { -bool     => 'transitive' } ) }
sub non_transitive ($self) { $self->search( { -not_bool => 'transitive' } ) }

1;
