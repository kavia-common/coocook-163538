package Coocook::Schema::Result::Item;

# ABSTRACT: each database row is 1 item of a purchase list and subsumes 1 or more dish ingredients

use Coocook::Base;
use Moose;
use namespace::autoclean;

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

__PACKAGE__->has_many( ingredients => 'Coocook::Schema::Result::DishIngredient', 'item_id' );

__PACKAGE__->meta->make_immutable;

sub convert ( $self, $unit2 ) {
    $self->txn_do(
        sub {
            my $unit1 = $self->unit;

            my $conversion = $self->result_source->schema->resultset('UnitConversion')->search(
                [    # OR
                    {
                        unit1_id => $unit1->id,
                        unit2_id => $unit2->id,
                    },
                    {
                        unit1_id => $unit2->id,
                        unit2_id => $unit1->id,
                    },

                ]
            )->single;

            $conversion
              or die "Conversion does not exist";

            my $factor =
                $conversion->unit1_id == $unit1->id ? $conversion->factor
              : $conversion->unit2_id == $unit1->id ? $conversion->factor**-1
              :                                       die "found conversion doesn't relate to unit1";

            my $unit2_item = $self->result_source->resultset->find(
                {
                    purchase_list_id => $self->purchase_list_id,
                    article_id       => $self->article_id,
                    unit_id          => $unit2->id,
                }
            );

            if ($unit2_item) {
                $unit2_item->update(
                    {
                        value  => $unit2_item->value + $self->value * $factor,
                        offset => $unit2_item->offset + $self->offset * $factor,
                    }
                );

                $self->ingredients->update( { item_id => $unit2_item->id } );

                $self->delete;

                return $unit2_item;
            }
            else {
                $self->update(
                    {
                        unit_id => $unit2->id,
                        value   => $self->value * $factor,
                        offset  => $self->offset * $factor,
                    }
                );

                return $self;
            }
        }
    );
}

sub update_from_ingredients ($self) {
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

    $self->update(
        {
            value  => $item_value,
            offset => 0
        }
    );
}

1;
