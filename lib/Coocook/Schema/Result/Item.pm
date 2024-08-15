package Coocook::Schema::Result::Item;

# ABSTRACT: each database row is 1 item of a purchase list and subsumes 1 or more dish ingredients

use Coocook::Base qw(Moose);

use Carp;

extends 'Coocook::Schema::Result';

__PACKAGE__->table('items');

__PACKAGE__->add_columns(
    id               => { data_type => 'integer', is_auto_increment => 1 },
    purchase_list_id => { data_type => 'integer' },
    value            => { data_type => 'real' },
    offset           => { data_type => 'real', default_value => 0 },
    unit_id          => { data_type => 'integer' },
    article_id       => { data_type => 'integer' },
    purchased        => { data_type => 'boolean', default_value => 0 },
    comment          => { data_type => 'text' },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->add_unique_constraints( [qw<purchase_list_id article_id unit_id>] );

__PACKAGE__->belongs_to(
    purchase_list => 'Coocook::Schema::Result::PurchaseList',
    'purchase_list_id'
);

__PACKAGE__->belongs_to( article => 'Coocook::Schema::Result::Article', 'article_id' );
__PACKAGE__->belongs_to( unit    => 'Coocook::Schema::Result::Unit',    'unit_id' );

__PACKAGE__->might_have(
    article_unit => 'Coocook::Schema::Result::ArticleUnit',
    {
        'foreign.article_id' => 'self.article_id',
        'foreign.unit_id'    => 'self.unit_id',
    },
    {
        is_foreign_key_constraint => 0,
        cascade_delete            => 0,
    }
);

__PACKAGE__->has_many(
    other_items => __PACKAGE__,
    sub ($args) {
        return {
            "$args->{foreign_alias}.id"               => { '!='   => { -ident => "$args->{self_alias}.id" } },
            "$args->{foreign_alias}.purchase_list_id" => { -ident => "$args->{self_alias}.purchase_list_id" },
        };
    }
);

__PACKAGE__->has_many( ingredients => 'Coocook::Schema::Result::DishIngredient', 'item_id' );

__PACKAGE__->meta->make_immutable;

sub change_value_offset_unit ( $self, $value, $offset, $unit_id ) {
    $self->txn_do(
        sub {
            my $existing_item = $self->result_source->resultset->find(
                {
                    purchase_list_id => $self->purchase_list_id,
                    article_id       => $self->article_id,
                    unit_id          => $unit_id,
                }
            );

            if ($existing_item) {
                $existing_item->update(
                    {
                        value  => $existing_item->value + $value,
                        offset => $existing_item->offset + $offset,
                    }
                );

                $self->ingredients->update( { item_id => $existing_item->id } );

                $self->delete;

                return $existing_item;
            }
            else {
                $self->update(
                    {
                        unit_id => $unit_id,
                        value   => $value,
                        offset  => $offset,
                    }
                );

                return $self;
            }
        }
    );
}

=head2 remove_ingredients( $union_conversion_graph, @ingredient_results )

Returns the updated C<Result::Item> or C<undef> if it has been deleted.

=cut

sub remove_ingredients ( $self, $ucg, @ingredients_to_remove ) {
    $self->txn_do(
        sub {
            my $recalculate_value;
            my $value = $self->value;

            for my $ingredient (@ingredients_to_remove) {
                $ingredient->item_id == $self->id
                  or croak "Can't remove ingredient that doesn't belong to this purchase list item";

                $ingredient->update( { item_id => undef } );

                next if $recalculate_value;

                if ( defined( my $factor = $ucg->factor_between_units( $ingredient->unit_id => $self->unit_id ) ) )
                {
                    $value -= $ingredient->value * $factor;

                    $value < 0 and $recalculate_value = 1;
                }
                else {
                    $recalculate_value = 1;
                }
            }

            if ($recalculate_value) {
                $value = 0;
                my $item_keeps_ingredients;

                for my $ingredient ( $self->ingredients->all ) {    # remaining ingredients
                    if ( defined( my $factor = $ucg->factor_between_units( $ingredient->unit_id => $self->unit_id ) ) )
                    {
                        $value                  += $ingredient->value * $factor;
                        $item_keeps_ingredients  = 1;
                    }
                    else {                                          # ingredient is added to other/new item of same unit
                        my $item = $self->other_items->add_or_create(
                            {
                                purchase_list_id => $self->purchase_list_id,
                                article_id       => $ingredient->article_id,
                                unit_id          => $ingredient->unit_id,
                                value            => $ingredient->value,
                            }
                        );
                        $ingredient->update( { item_id => $item->id } );
                    }
                }

                if ( not $item_keeps_ingredients ) {
                    $self->delete();
                    return;
                }
            }
            elsif ( not $self->ingredients->results_exist ) {
                $self->delete();
                return;
            }

            return $self->update( { value => $value } );
        }
    );
}

=head2 total()

Returns total, i.e. sum of the item's value and offset.

=cut

sub total ($self) { return $self->value + $self->offset }

sub update_from_ingredients ($self) {
    my $old_value  = $self->value;
    my $item_value = 0;

    for my $ingredient ( $self->ingredients->all ) {

        my $ingredient_value = $ingredient->value;

        if ( $self->unit_id != $ingredient->unit_id ) {
            my $unit1 = $ingredient->unit;
            my $unit2 = $self->unit;

            if ( my $conversion = $unit1->conversions_from->find( { unit2_id => $unit2->id } ) ) {
                $ingredient_value *= $conversion->factor;
            }
            elsif ( $conversion = $unit2->conversions_from->find( { unit2_id => $unit1->id } ) ) {
                $ingredient_value *= $conversion->factor**-1;
            }
            else {
                die "Can't convert between units";
            }
        }

        $item_value += $ingredient_value;
    }

    if ( $item_value == $old_value ) {
        return $self;
    }

    $self->set_column( value => $item_value );

    my $delta  = $item_value - $old_value;
    my $offset = $self->offset;

    if (   ( $delta < 0 and $offset < 0 )
        or ( $delta > 0 and $offset > 0 ) )    # both are negative or both positive
    {
        if ( abs($delta) <= abs($offset) ) {    # fill up offset if possible
            $offset -= $delta;
            return $self->update( { offset => $offset } );
        }
    }

    $self->update( { offset => 0 } );           # otherwise clear offset
}

1;
