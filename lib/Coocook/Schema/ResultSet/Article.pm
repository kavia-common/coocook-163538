package Coocook::Schema::ResultSet::Article;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::ResultSet';

__PACKAGE__->load_components(
    '+Coocook::Schema::Component::ResultSet::ArticleOrUnit',
    '+Coocook::Schema::Component::ResultSet::SortByName',
);

__PACKAGE__->meta->make_immutable;

1;
