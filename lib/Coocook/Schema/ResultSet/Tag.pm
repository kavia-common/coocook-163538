package Coocook::Schema::ResultSet::Tag;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::ResultSet';

__PACKAGE__->load_components('+Coocook::Schema::Component::ResultSet::SortByName');

sub ungrouped ($self) {
    return $self->search( { $self->me('tag_group') => undef } );
}

__PACKAGE__->meta->make_immutable;

1;
