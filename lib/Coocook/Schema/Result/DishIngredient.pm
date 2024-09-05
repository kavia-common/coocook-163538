package Coocook::Schema::Result::DishIngredient;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::Result';

__PACKAGE__->load_components(
    qw<
      Ordered
      +Coocook::Schema::Component::Result::Ingredient
    >
);

__PACKAGE__->table('dish_ingredients');

__PACKAGE__->add_columns(
    id         => { data_type => 'integer', is_auto_increment => 1 },
    position   => { data_type => 'integer', default_value     => 1 },
    dish_id    => { data_type => 'integer' },
    prepare    => { data_type => 'boolean' },
    article_id => { data_type => 'integer' },
    unit_id    => { data_type => 'integer' },
    value      => { data_type => 'real' },
    comment    => { data_type => 'text' },
    item_id    => { data_type => 'integer', is_nullable => 1 },    # from purchase list
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->position_column('position');
__PACKAGE__->grouping_column( [ 'dish_id', 'prepare' ] );

__PACKAGE__->belongs_to( article => 'Coocook::Schema::Result::Article', 'article_id' );
__PACKAGE__->belongs_to( dish    => 'Coocook::Schema::Result::Dish',    'dish_id' );
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

__PACKAGE__->belongs_to(
    item => 'Coocook::Schema::Result::Item',
    'item_id', { on_delete => 'SET NULL' }
);

__PACKAGE__->has_many(
    other_ingredients_on_item => 'Coocook::Schema::Result::DishIngredient',
    sub ($args) {
        return {
            "$args->{foreign_alias}.id"      => { '!='   => { -ident => "$args->{self_alias}.id" } },
            "$args->{foreign_alias}.item_id" => { -ident => "$args->{self_alias}.item_id" },
        };
    }
);

__PACKAGE__->meta->make_immutable;

sub assign_to_purchase_list ( $self, $list ) {
    my $item;

    $self->txn_do(
        sub {
            $item = $self->result_source->schema->resultset('Item')->add_or_create(
                {
                    purchase_list_id => ref $list ? $list->id : $list,    # TODO stricter interface?
                    article_id       => $self->article_id,
                    unit_id          => $self->unit_id,
                    value            => $self->value,
                }
            );

            $self->update( { item_id => $item->id } );
        }
    );

    return $item;
}

=head2 delete_update_item()

=cut

sub delete_update_item ($self) {
    my $retval = $self->item_id && $self->set_value_update_item(0);
    $self->delete();
    return $retval;
}

=head2 set_value_update_item( $value, $ucg? )

=cut

sub set_value_update_item ( $self, $new_value, $ucg = undef ) {
    $self->txn_do(
        sub {
            my $item = $self->item
              or return $self->update( { value => $new_value } );

            my $old_value = $self->value;

            if ( $old_value == 0 ) {
                $self->update( { item_id => undef, value => $new_value } );

                my $purchase_list = $item->purchase_list;

                if ( $item->ingredients->count == 0 ) {    # TODO use results_exist()
                    $item->delete();
                    $item = undef;
                }

                if ( $new_value > 0 ) {
                    return $self->assign_to_purchase_list($purchase_list);
                }
                else {
                    return $item;
                }
            }

            if ( $new_value == 0 and not $self->other_ingredients_on_item->results_exist ) {
                $self->update( { item_id => undef, value => 0 } );
                $item->delete();
                return;
            }

            $self->update( { value => $new_value } );

            $ucg ||= $item->purchase_list->project->unit_conversion_graph;

            if ( my $factor = $ucg->factor_between_units( $self->unit_id => $item->unit_id ) ) {
                if ( $self->other_ingredients_on_item->results_exist ) {
                    return $item->delta_to_value_offset( ( $new_value - $old_value ) * $factor );
                }
                else {
                    return $item->set_value_offset( $new_value * $factor );
                }
            }

            # no factor to item unit -> whole item needs to be rebuilt
            return $item->update_from_ingredients();
        }
    );
}

=head2 set_value_unit_update_item( $value, $unit, $ucg? )

=cut

sub set_value_unit_update_item ( $self, $new_value, $new_unit_id, $ucg = undef ) {
    $self->txn_do(
        sub {
            my $item = $self->item
              or return $self->update( { value => $new_value, unit_id => $new_unit_id } );

            $ucg ||= $item->purchase_list->project->unit_conversion_graph;

            my $old_value   = $self->value;
            my $old_unit_id = $self->unit_id;

            my $factor_ingredient = $ucg->factor_between_units( $old_unit_id => $new_unit_id );
            my $factor_item       = $ucg->factor_between_units( $old_unit_id => $item->unit_id );

            if ( $factor_ingredient and $factor_item ) {
                $self->update( { value => $new_value, unit_id => $new_unit_id } );

                my $delta = ( $new_value / $factor_ingredient - $old_value ) * $factor_item;
                return $item->delta_to_value_offset($delta);
            }

            $self->set_value_update_item(0);
            $self->update( { value => $new_value, unit_id => $new_unit_id } );
            $self->assign_to_purchase_list( $item->purchase_list );
        }
    );
}

sub for_ingredients_editor ($self) {
    my $unit              = $self->unit;
    my @convertible_units = $self->article->units->search(
        {
            id => { '!=' => $unit->id },
        }
    )->all;

    # transform Result::Unit objects into plain hashes
    for ( $unit, @convertible_units ) {
        my $u = $_;

        $_ = { map { $_ => $u->get_column($_) } qw<id short_name long_name> };
    }

    return {
        id           => $self->id,
        prepare      => $self->prepare,
        position     => $self->position,
        value        => $self->value,
        comment      => $self->comment,
        article      => { name => $self->article->name, comment => $self->article->comment },
        current_unit => $unit,
        units        => \@convertible_units,
    };
}

1;
