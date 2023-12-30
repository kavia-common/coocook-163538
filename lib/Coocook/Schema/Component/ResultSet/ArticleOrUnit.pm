package Coocook::Schema::Component::ResultSet::ArticleOrUnit;

# ABSTRACT: methods shared between ResultSet::Article and ResultSet::Unit

use Coocook::Base;

my @relationships = qw<
  dish_ingredients
  recipe_ingredients
  items
>;

=head2 in_use($cond?)

Returns a new resultset with articles/units which have any of
dish ingredients, recipe ingredients or purchase list items.

=cut

# TODO could this be self-relation 'in_use' in Article/Unit + 'units_in_use' in Article?
sub in_use ( $self, $cond = undef ) {
    return $self->search(
        [    # OR
            map { $self->correlate($_)->results_exist_as_query($cond) } @relationships
        ]
    );
}

=head2 with_number_of_ingredients_items()

Returns a new resultset with 3 virtual columns with
an integer showing the number of dish ingredients,
recipe ingredients and purchase list items that use
this article/unit.

=cut

sub with_number_of_ingredients_items {
    my $self = shift;

    return $self->search(
        undef,
        {
            '+columns' => {
                map { 'number_of_' . $_ => $self->correlate($_)->search(@_)->count_rs->as_query } @relationships
            }
        }
    );
}

1;
