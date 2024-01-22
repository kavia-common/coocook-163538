package Coocook::Schema::Result::DishIngredient;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::Result';

__PACKAGE__->load_components(qw< Ordered >);

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

=head2 update_on_purchase_list()

Returns boolish value indicating if there's an item that was updated

=cut

sub update_on_purchase_list ($self) {
    $self->txn_do(
        sub {
            my $item = $self->item or return;

            $item->update_from_ingredients;
        }
    ) or return;

    return 1;
}

=head2 remove_from_purchase_list()

Returns boolish value indicating if there's an item that was updated

=cut

sub remove_from_purchase_list ($self) {
    $self->txn_do(
        sub {
            my $item = $self->item or return;

            $self->update( { item_id => undef } );

            if ( $item->ingredients->results_exist ) {
                $item->update_from_ingredients;
            }

            else {    # item belongs to no other ingredients
                $item->delete;
            }
        }
    ) or return;

    return 1;
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
