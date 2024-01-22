package Coocook::Schema::ResultSet::Unit;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::ResultSet';

sub sorted_by_columns { 'long_name' }

__PACKAGE__->load_components(
    '+Coocook::Schema::Component::ResultSet::ArticleOrUnit',
    '+Coocook::Schema::Component::ResultSet::SortByName',
);

__PACKAGE__->meta->make_immutable;

1;
