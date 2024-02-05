package Coocook::Schema::ResultSet::PurchaseList;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::ResultSet';

__PACKAGE__->load_components('+Coocook::Schema::Component::ResultSet::SortByName');
sub sorted_by_columns { 'date', 'name' }

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head2 with_is_default()

Returns a new ResultSet with an additional column C<is_default>
with a boolean value indicating whether any purchase list
is their project’s default purchase list.

=cut

sub with_is_default ($self) {
    my $projects = $self->correlate('project');
    return $self->search(
        undef,
        {
            '+columns' => {
                is_default => $projects->results_exist_as_query(
                    {
                        $projects->me('default_purchase_list_id') => { -ident => $self->me('id') },
                    }
                ),
            },
        }
    );
}

sub with_items_count ($self) {
    return $self->search(
        undef,
        {
            '+columns' => { items_count => $self->correlate('items')->count_rs->as_query },
        }
    );
}

1;
