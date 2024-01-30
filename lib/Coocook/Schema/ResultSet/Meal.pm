package Coocook::Schema::ResultSet::Meal;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::ResultSet';

sub order_by_columns { qw< date id > }    # TODO add sorting of meals

__PACKAGE__->load_components('+Coocook::Schema::Component::ResultSet::SortByName');

__PACKAGE__->meta->make_immutable;

1;
