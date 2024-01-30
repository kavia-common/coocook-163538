package Coocook::Schema::ResultSet::PurchaseList;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::ResultSet';

__PACKAGE__->load_components('+Coocook::Schema::Component::ResultSet::SortByName');
sub sorted_by_columns { 'date', 'name' }

__PACKAGE__->meta->make_immutable;

sub with_item_count ($self) {
    return $self->search(
        undef,
        {
            '+columns' => { item_count => $self->correlate('items')->count_rs->as_query },
        }
    );
}

1;
