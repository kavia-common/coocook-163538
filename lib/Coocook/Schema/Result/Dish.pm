package Coocook::Schema::Result::Dish;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::Result';

__PACKAGE__->load_components(
    qw<
      +Coocook::Schema::Component::Result::DishOrRecipe
    >
);

__PACKAGE__->load_components(qw< Ordered >);

__PACKAGE__->table('dishes');

__PACKAGE__->add_columns(
    id                 => { data_type => 'integer', is_auto_increment => 1 },
    meal_id            => { data_type => 'integer' },
    position           => { data_type => 'integer' },
    from_recipe_id     => { data_type => 'integer', is_nullable => 1 },
    name               => { data_type => 'text' },
    servings           => { data_type => 'integer' },
    prepare_at_meal_id => { data_type => 'integer', is_nullable => 1 },
    preparation        => { data_type => 'text' },
    description        => { data_type => 'text' },
    comment            => { data_type => 'text' },
);

__PACKAGE__->set_primary_key('id');

# TODO __PACKAGE__->add_unique_constraints([qw<meal_id name>]);

__PACKAGE__->position_column('position');
__PACKAGE__->grouping_column('meal_id');

__PACKAGE__->belongs_to( meal => 'Coocook::Schema::Result::Meal', 'meal_id' );

__PACKAGE__->belongs_to(
    prepare_at_meal => 'Coocook::Schema::Result::Meal',
    'prepare_at_meal_id', { join_type => 'left' }
);

__PACKAGE__->belongs_to(
    recipe => 'Coocook::Schema::Result::Recipe',
    'from_recipe_id', { join_type => 'left' }
);

__PACKAGE__->has_many( ingredients => 'Coocook::Schema::Result::DishIngredient', 'dish_id' );
__PACKAGE__->many_to_many( items => ingredients => 'item' );

__PACKAGE__->has_many(
    ingredients_ordered => 'Coocook::Schema::Result::DishIngredient',
    'dish_id', { order_by => 'position' }
);

__PACKAGE__->has_many( dishes_tags => 'Coocook::Schema::Result::DishTag', 'dish_id' );
__PACKAGE__->many_to_many( tags => dishes_tags => 'tag' );

__PACKAGE__->meta->make_immutable;

sub delete_update_items ($self) {
    $self->txn_do(
        sub {
            for my $ingredient ( $self->ingredients->all ) {
                $ingredient->delete_update_item;
            }
            $self->delete;
        }
    );
}

sub for_meals_dishes_editor ($self) {
    return { $self->as_hashref->%*, date => $self->meal->date->ymd };
}

1;
