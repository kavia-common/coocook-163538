package Coocook::Schema::ResultSet::ShopSection;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::ResultSet';

__PACKAGE__->load_components('+Coocook::Schema::Component::ResultSet::SortByName');

__PACKAGE__->meta->make_immutable;

sub with_articles_count ($self) {
    return $self->search(
        undef,
        {
            '+columns' => { articles_count => $self->correlate('articles')->count_rs->as_query },
        }
    );
}

1;
