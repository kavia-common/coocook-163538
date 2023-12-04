package Coocook::Schema::ResultSet::ShopSection;

use Coocook::Base;
use Moose;
use namespace::autoclean;

extends 'Coocook::Schema::ResultSet';

__PACKAGE__->load_components('+Coocook::Schema::Component::ResultSet::SortByName');

__PACKAGE__->meta->make_immutable;

sub with_article_count ($self) {
    return $self->search(
        undef,
        {
            '+columns' => { article_count => $self->correlate('articles')->count_rs->as_query },
        }
    );
}

1;
