package Coocook::Schema::ResultSet::UnitConversion;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::ResultSet';

__PACKAGE__->meta->make_immutable;

sub normalized     ($self) { $self->search( { unit1_id => { '<' => { -ident => 'unit2_id' } } } ) }
sub not_normalized ($self) { $self->search( { unit1_id => { '>' => { -ident => 'unit2_id' } } } ) }

sub transitive     ($self) { $self->search( { -bool     => 'transitive' } ) }
sub non_transitive ($self) { $self->search( { -not_bool => 'transitive' } ) }

1;
