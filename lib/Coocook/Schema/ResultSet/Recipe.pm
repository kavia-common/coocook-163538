package Coocook::Schema::ResultSet::Recipe;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::ResultSet';

__PACKAGE__->load_components('+Coocook::Schema::Component::ResultSet::SortByName');

__PACKAGE__->meta->make_immutable;

sub public ($self) {
    return $self->search(
        {
            -bool => 'project.is_public',
        },
        {
            join => 'project',
        }
    );
}

1;
