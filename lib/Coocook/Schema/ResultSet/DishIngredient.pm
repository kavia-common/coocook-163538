package Coocook::Schema::ResultSet::DishIngredient;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::ResultSet';

sub sorted_by_columns { 'position' }

__PACKAGE__->load_components('+Coocook::Schema::Component::ResultSet::SortByName');

__PACKAGE__->meta->make_immutable;

sub prepared ($self) {
    return $self->search( { -bool => $self->me('prepare') } );
}

sub unassigned ($self) {
    return $self->search( { item_id => undef } );
}

1;
