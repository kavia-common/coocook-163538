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

    $c->stash(
        dish => $c->project->dishes->search(
            undef,
            {
                prefetch => [ 'meal', 'recipe' ],
            }
        )->find($id)
          || $c->detach('/error/not_found')
    );
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

    $c->stash->{json}{'ingredients-editor-data'} = {
        project_id   => $c->project->id,
        project_name => $c->project->url_name,
        dish_id      => $dish->id,
    };

    $c->stash(
        dish => $dish->as_hashref(
            tags_joined => $dish->tags_rs->joined,
            meal        => $dish->meal,
            recipe      => $dish->recipe
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

    $c->stash->{dish}->update_items_and_delete;

    $c->response->redirect( $c->project_uri('/project/edit') );
}

sub delete_ajax : POST Chained('base') Does(~Ajax) PathPart('delete/ajax') Args(0)
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    $c->stash->{dish}->update_items_and_delete;

    $c->stash->{json_data} = { success => 1 };
}

sub create : POST Chained('/project/base') PathPart('dishes/create') Does(~Ajax) Args(0)
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $meal = $c->project->meals->find( $c->req->body_data->{meal_id} );

    my $json_dish = $c->req->body_data->{dish};

    my $dish = $meal->create_related(
        dishes => {
            servings           => $json_dish->{servings},
            name               => $json_dish->{name},
            description        => $json_dish->{description} // "",
            comment            => $json_dish->{comment}     // "",
            preparation        => $json_dish->{preparation} // "",
            prepare_at_meal_id => $json_dish->{prepare_at_meal} || undef,
        }
    );

    $c->stash->{json_data} = { dish => $dish->for_meals_dishes_editor };
}

sub from_recipe : POST Chained('/project/base') PathPart('dishes/from_recipe') Args(0)
  RequiresCapability('edit_project') Does(~Ajax) {
    my ( $self, $c ) = @_;

    my $meal   = $c->project->meals->find( $c->req->body_data->{meal_id} );
    my $recipe = $c->project->recipes->find( $c->req->body_data->{recipe_id} );

    my $dish = $c->model('DB::Dish')->from_recipe(
        $recipe,
        (
            meal     => $meal->id,
            servings => $c->req->body_data->{servings},
            comment  => $c->req->body_data->{comment} // "",
        )
    );

    $c->stash->{json_data} = {
        $dish->for_meals_dishes_editor->%*,
        delete_url => $c->project_uri( '/dish/delete_ajax', $dish->id )->as_string,
        update_url => $c->project_uri( '/dish/update_ajax', $dish->id )->as_string,
    };
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

            my $tags = $c->project->tags->from_names( $c->req->params->get('tags') );
            $dish->set_tags( [ $tags->all ] );
        }
    );

    $c->detach( redirect => [ $dish->id, '#ingredients' ] );
}

sub update_ajax : POST Chained('base') PathPart('update/ajax') Does(~Ajax) Args(0)
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $dish = $c->stash->{dish};

    $dish->txn_do(
        sub {
            $dish->update(
                {
                    name               => $c->req->body_data->{name},
                    comment            => $c->req->body_data->{comment},
                    servings           => $c->req->body_data->{servings},
                    preparation        => $c->req->body_data->{preparation},
                    description        => $c->req->body_data->{description},
                    prepare_at_meal_id => $c->req->body_data->{prepare_at_meal} || undef,

                }
            );

            my $tags = $c->project->tags->from_names( $c->req->body_data->{tags} );
            $dish->set_tags( [ $tags->all ] );
        }
    );

    $c->stash->{json_data} = $dish->for_meals_dishes_editor;
}

sub reposition : POST Chained('/project/base') PathPart('dish_ingredient/reposition') Args(1)
  RequiresCapability('edit_project') {
    my ( $self, $c, $id ) = @_;

    my $ingredient = $c->project->dishes->search_related('ingredients')->find($id);

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
