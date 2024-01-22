package Coocook::Schema::Result::Unit;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::Result';

__PACKAGE__->table('units');

__PACKAGE__->add_columns(
    id         => { data_type => 'integer', is_auto_increment => 1 },
    project_id => { data_type => 'integer' },
    short_name => { data_type => 'text' },
    long_name  => { data_type => 'text' },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->add_unique_constraints( [ 'project_id', 'long_name' ] );

__PACKAGE__->belongs_to( project => 'Coocook::Schema::Result::Project', 'project_id' );

# for doc see https://metacpan.org/pod/DBIx::Class::Relationship::Base#Custom-join-conditions
__PACKAGE__->has_many(
    conversions => 'Coocook::Schema::Result::UnitConversion',
    sub ($args) {    # custom relationship constraint required for OR condition
        return [     # OR
            "$args->{foreign_alias}.unit1_id" => { -ident => "$args->{self_alias}.id" },
            "$args->{foreign_alias}.unit2_id" => { -ident => "$args->{self_alias}.id" },
        ];
    }
);

__PACKAGE__->has_many(
    conversions_from => 'Coocook::Schema::Result::UnitConversion',
    'unit1_id', { cascade_delete => 1 }
);

__PACKAGE__->has_many(
    conversions_to => 'Coocook::Schema::Result::UnitConversion',
    'unit2_id', { cascade_delete => 1 }
);

__PACKAGE__->has_many(
    other_units => 'Coocook::Schema::Result::Unit',
    sub ($args) {
        return {
            "$args->{foreign_alias}.id"         => { '!='   => { -ident => "$args->{self_alias}.id" } },
            "$args->{foreign_alias}.project_id" => { -ident => "$args->{self_alias}.project_id" },
        };
    }
);

__PACKAGE__->has_many(
    articles_units => 'Coocook::Schema::Result::ArticleUnit',
    'unit_id',
    {
        cascade_delete => 0,    # units with articles_units may not be deleted
    }
);
__PACKAGE__->many_to_many( articles => articles_units => 'article' );

__PACKAGE__->has_many(
    dish_ingredients => 'Coocook::Schema::Result::DishIngredient',
    'unit_id',
    {
        cascade_delete => 0,    # units with dish_ingredients may not be deleted
    }
);
__PACKAGE__->many_to_many( dishes => dish_ingredients => 'dish' );

__PACKAGE__->has_many(
    recipe_ingredients => 'Coocook::Schema::Result::RecipeIngredient',
    'unit_id',
    {
        cascade_delete => 0,    # units with recipe_ingredients may not be deleted
    }
);
__PACKAGE__->many_to_many( recipes => recipe_ingredients => 'recipe' );

__PACKAGE__->has_many(
    items => 'Coocook::Schema::Result::Item',
    'unit_id',
    {
        cascade_delete => 0,    # units with items may not be deleted
    }
);

__PACKAGE__->meta->make_immutable;

# looks like a many_to_many() relationship shortcut
# but needs to be implemented by hand because other unit can be unit1 or unit2
sub convertible_into ($self) {
    return $self->other_units->search(
        [    # OR
            'conversions.unit1_id' => $self->id,
            'conversions.unit2_id' => $self->id,
        ],
        {
            join => 'conversions',
        }
    )->all;
}

sub find_conversion_into ( $self, $unit_id ) {
    return $self->result_source->schema->resultset('UnitConversion')->search(
        [    # OR
            {
                unit1_id => $self->id,
                unit2_id => $unit_id,
            },
            {
                unit1_id => $unit_id,
                unit2_id => $self->id,
            }
        ]
    )->single;
}

1;
