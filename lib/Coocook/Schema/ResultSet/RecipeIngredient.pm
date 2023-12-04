package Coocook::Schema::ResultSet::RecipeIngredient;

use Coocook::Base;
use Moose;
use namespace::autoclean;

extends 'Coocook::Schema::ResultSet';

sub sorted_by_columns { 'position' }

__PACKAGE__->load_components('+Coocook::Schema::Component::ResultSet::SortByName');

__PACKAGE__->meta->make_immutable;

sub prepared     ($self) { $self->search( { -bool     => 'prepare' } ) }
sub not_prepared ($self) { $self->search( { -not_bool => 'prepare' } ) }

1;
