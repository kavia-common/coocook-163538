package Coocook::Schema::ResultSet::UnitConversion;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::ResultSet';

__PACKAGE__->meta->make_immutable;

sub as_graph ($self) {
    require Coocook::Model::UnitConversionGraph;    # lazy loading for faster loading of Schema
    return Coocook::Model::UnitConversionGraph->new($self);
}

sub normalized     ($self) { $self->search( { unit1_id => { '<' => { -ident => 'unit2_id' } } } ) }
sub not_normalized ($self) { $self->search( { unit1_id => { '>' => { -ident => 'unit2_id' } } } ) }

sub transitive     ($self) { $self->search( { -bool     => 'transitive' } ) }
sub non_transitive ($self) { $self->search( { -not_bool => 'transitive' } ) }

1;
