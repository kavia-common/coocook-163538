package Coocook::Schema::ResultSet::PurchaseList;

use Coocook::Base qw(Moose);

use DateTime;

extends 'Coocook::Schema::ResultSet';

__PACKAGE__->load_components('+Coocook::Schema::Component::ResultSet::SortByName');
sub sorted_by_columns { 'date', 'name' }

__PACKAGE__->meta->make_immutable;

=head2 default_date( $min_date? )

Returns a L<DateTime> object of a useful date for new purchase list.
Either date after last purchase list in ResultSet or C<$min_date>
(which is by default today).

=cut

sub default_date ( $self, $min_date = DateTime->today ) {
    my $last_list =
      $self->search( undef, { columns => 'date', order_by => { -desc => 'date' } } )->one_row;

    my $date = ( $last_list and $min_date < $last_list->date )
      ? $last_list->date    # doesn't need cloning because short-lived object
      : $min_date->clone;

    return $date->add( days => 1 );
}

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
