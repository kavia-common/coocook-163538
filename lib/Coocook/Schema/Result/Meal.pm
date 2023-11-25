package Coocook::Schema::Result::Meal;

use Coocook::Base;
use Moose;
use namespace::autoclean;

use JSON::MaybeXS;

extends 'Coocook::Schema::Result';

__PACKAGE__->load_components(qw< Ordered >);

__PACKAGE__->table('meals');

__PACKAGE__->add_columns(
    id         => { data_type => 'integer', is_auto_increment => 1 },
    project_id => { data_type => 'integer' },
    position   => { data_type => 'integer' },
    date       => { data_type => 'date' },
    name       => { data_type => 'text' },
    comment    => { data_type => 'text' },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->add_unique_constraints( [qw<project_id date name>] );

__PACKAGE__->position_column('position');
__PACKAGE__->grouping_column( [ 'project_id', 'date' ] );

__PACKAGE__->belongs_to( project => 'Coocook::Schema::Result::Project', 'project_id' );

__PACKAGE__->has_many(
    dishes => 'Coocook::Schema::Result::Dish',
    'meal_id',
    {
        cascade_delete => 1,    # TODO meals with dishes should not be deleted in the user interface
                                # but dishes have no FK on project, so CASCADE is necessary
    }
);

__PACKAGE__->has_many(
    prepared_dishes => 'Coocook::Schema::Result::Dish',
    'prepare_at_meal_id',
    {
        cascade_delete => 0,    # meals with prepared dishes may not be deleted
    }
);

__PACKAGE__->meta->make_immutable;

sub deletable ($self) {
    return ( !$self->dishes->results_exist and !$self->prepared_dishes->results_exist );
}

=head2 delete_dishes

Deletes all but prepared dishes

=cut

sub delete_dishes ($self) {
    $self->dishes->update_items_and_delete;
}

sub for_meals_dishes_editor ($self) {
    my @cols = qw( meal_id comment id name prepare_at_meal_id servings position );

    my $related_dishes  = $self->search_related( dishes          => ( undef, { columns => \@cols } ) );
    my $prepared_dishes = $self->search_related( prepared_dishes => ( undef, { columns => \@cols } ) );

    return $self->as_hashref(
        date            => $self->date->ymd,
        deletable       => $self->deletable ? JSON()->true : JSON()->false,
        dishes          => { map { $_->id => $_->for_meals_dishes_editor } $related_dishes->all },
        prepared_dishes => { map { $_->id => $_->for_meals_dishes_editor } $prepared_dishes->all },
    );

}

1;
