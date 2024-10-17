package Coocook::Controller::Dish;

use Coocook::Base qw(Moose);

BEGIN { extends 'Coocook::Controller' }

=head1 NAME

Coocook::Controller::Dish - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub base : Chained('/project/submenu') PathPart('dish') CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;

    $c->stash( dish => $c->project->dishes->find( $id, { prefetch => [ 'meal', 'recipe' ] } )
          || $c->detach('/error/object_not_found') );
}

sub edit : GET HEAD Chained('base') PathPart('') Args(0) RequiresCapability('view_project') {
    my ( $self, $c ) = @_;

    my $dish = $c->stash->{dish};

    my $ingredients = $c->model('Ingredients')->new(
        project     => $c->project,
        ingredients => $dish->ingredients,
    );

    # candidate meals for preparing this dish: same day or earlier
    my $meals = $c->project->meals;
    my $prepare_meals =
      $meals->search( { date => { '<=' => $meals->format_date( $dish->meal->date ) } },
        { order_by => 'date' } );

    $c->json_stash(
        ingredients_editor_data => {
            project_id   => $c->project->id,
            project_name => $c->project->url_name,
            dish_id      => $dish->id,
        },
        available_tags => [ $c->project->tags->hri->sorted->all ],
        dish_tags      => [ $dish->tags_rs->sorted->get_column('name')->all ],
    );

    $c->stash(
        dish => $dish->as_hashref(
            meal   => $dish->meal,
            recipe => $dish->recipe
            ? {
                name => $dish->recipe->name,
                url  => $c->project_uri( '/recipe/edit', $dish->recipe->id ),
              }
            : undef,

            recalculate_url => $c->project_uri( $self->action_for('recalculate'), $dish->id ),
            update_url      => $c->project_uri( $self->action_for('update'),      $dish->id ),
        ),
        ingredients        => $ingredients->as_arrayref,
        articles           => $ingredients->all_articles,
        units              => $ingredients->all_units,
        prepare_meals      => [ $prepare_meals->all ],
        add_ingredient_url => $c->project_uri( '/dish/add',    $dish->id ),
        delete_url         => $c->project_uri( '/dish/delete', $dish->id ),
    );

    for my $ingredient ( $c->stash->{ingredients}->@* ) {
        $ingredient->{reposition_url} = $c->project_uri( '/dish/reposition', $ingredient->{id} );
    }
}

sub delete : POST Chained('base') PathPart('delete') Args(0) RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    $c->stash->{dish}->delete_update_items;

    $c->response->redirect( $c->project_uri('/project/edit') );
}

sub recalculate : POST Chained('base') Args(0) RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $dish = $c->stash->{dish};

    $dish->recalculate( $c->req->params->get('servings') );

    $c->detach( redirect => [ $dish->id, '#ingredients' ] );
}

sub add : POST Chained('base') Args(0) RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $dish = $c->stash->{dish};

    $dish->create_related(
        ingredients => {
            article_id => $c->req->params->get('article'),
            value      => $c->req->params->get('value') + 0,
            unit_id    => $c->req->params->get('unit'),
            comment    => $c->req->params->get('comment'),
            prepare    => $dish->format_bool( !!$c->req->params->get('prepare') ),
        }
    );

    $c->detach( redirect => [ $dish->id, '#ingredients' ] );
}

sub update : POST Chained('base') Args(0) RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $dish = $c->stash->{dish};

    $dish->txn_do(
        sub {
            $dish->update(
                {
                    name               => $c->req->params->get('name'),
                    comment            => $c->req->params->get('comment'),
                    servings           => $c->req->params->get('servings'),
                    preparation        => $c->req->params->get('preparation'),
                    description        => $c->req->params->get('description'),
                    prepare_at_meal_id => $c->req->params->get('prepare_at_meal') || undef,

                }
            );

            my @tag_ids =
              $c->project->find_or_create_tags_from_names( $c->req->params->get_all('tags') )->only_id_col->all;

            $dish->set_tags( \@tag_ids );
        }
    );

    $c->detach( redirect => [ $dish->id, '#ingredients' ] );
}

sub reposition : POST Chained('/project/base') PathPart('dish_ingredient/reposition') Args(1)
  RequiresCapability('edit_project') {
    my ( $self, $c, $id ) = @_;

    my $ingredient = $c->project->dishes->find_related( ingredients => $id );

    if ( $c->req->params->get('up') ) {
        $ingredient->move_previous();
    }
    elsif ( $c->req->params->get('down') ) {
        $ingredient->move_next();
    }
    else {
        die "No valid movement";
    }

    $c->detach( redirect => [ $ingredient->dish_id, '#ingredients' ] );
}

sub redirect : Private {
    my ( $self, $c, $id, $fragment ) = @_;

    $c->response->redirect( $c->project_uri( $self->action_for('edit'), $id ) . ( $fragment // '' ) );
}

__PACKAGE__->meta->make_immutable;

1;
