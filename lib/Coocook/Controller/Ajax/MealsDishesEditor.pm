package Coocook::Controller::Ajax::MealsDishesEditor;

use Coocook::Base qw(Moose);

use DateTime;

BEGIN { extends 'Coocook::Controller' }

# default Catalyst logic doesn't convert CamelCase to snake_case
# and compiles 'MealsDishesEditor' into 'mealsdisheseditor'
__PACKAGE__->config( namespace => 'ajax/meals_dishes_editor' );

=head1 NAME

Coocook::Controller::Ajax::MealsDishesEditor - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 General Methods

=cut

sub get_project_plan : GET HEAD Chained('/project/base') PathPart('project_plan') Args(0)
  RequiresCapability('view_project') {
    my ( $self, $c ) = @_;

    my $days = $c->model('Plan')->project_for_meals_dishes_editor( $c->project );

    for my $day ( keys %$days ) {
        for my $meal_key ( keys $days->{$day}->%* ) {
            my $meal = $days->{$day}{$meal_key};
            $meal->{delete_url} = $c->project_uri( $self->action_for('delete_meal'), $meal->{id} )->as_string;
            $meal->{update_url} = $c->project_uri( $self->action_for('update_meal'), $meal->{id} )->as_string;
            $meal->{delete_dishes_url} =
              $c->project_uri( $self->action_for('delete_dishes_from_meal'), $meal->{id} )->as_string;

            for my $dish_key ( keys $meal->{dishes}->%* ) {
                my $dish = $meal->{dishes}{$dish_key};
                $dish->{delete_url} = $c->project_uri( $self->action_for('delete_dish'), $dish->{id} )->as_string;
                $dish->{update_url} = $c->project_uri( $self->action_for('update_dish'), $dish->{id} )->as_string;
            }
        }
    }

    $c->stash->{ajax_response} = {
        project_plan         => $days,
        get_project_plan_url => $c->project_uri( $self->action_for('get_project_plan') )->as_string,
        move_meal_dish_url   => $c->project_uri( $self->action_for('move_meal_or_dish') )->as_string,
    };
}

sub get_recipes : GET HEAD Chained('/recipe/recipes') PathPart('ajax')
  RequiresCapability('view_project') Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{ajax_response} = {
        recipes             => $c->stash->{recipes},
        get_all_recipes_url => $c->project_uri( $c->action )->as_string,
    };
}

=head2 Meal/Dish Management

=head3 move_meal_or_dish()

Move a Meal before or after another Meal or move a Dish to another Meal or before or after
another Dish.

=head3 Errors

=over 4

=item UNQMEAL
The name of a meal should be unique per day. For this reason, this method throws an error when it tries
to move a meal with a name which already exists on the target date.

=back

=cut

sub move_meal_or_dish : POST Chained('/project/base') PathPart('move_meal_dish') Args(0)
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $project = $c->project;

    my $source_path = $c->req->body_data->{source_path} || $c->detach('/error/bad_request');
    my $target_path = $c->req->body_data->{target_path} || $c->detach('/error/bad_request');
    my $direction   = $c->req->body_data->{direction}   || $c->detach('/error/bad_request');

    my $plan = $c->model('Plan');

    my $moved = $plan->resolve_meal_dish_path( $project, $source_path )
      or $c->detach( '/error/bad_request', [ { message => 'Invalid source_path' } ] );

    my $target = $plan->resolve_meal_dish_path( $project, $target_path )
      or $c->detach( '/error/bad_request', [ { message => 'Invalid target_path' } ] );

    if (    $source_path->{item_type} eq 'dish'
        and $target_path->{item_type} eq 'dish' )
    {
        $moved->move_to_group( { meal_id => $target->meal->id }, $target->position );
    }
    elsif ( $source_path->{item_type} eq 'dish'
        and $target_path->{item_type} eq 'meal' )
    {
        $moved->move_to_group( { meal_id => $target->id }, $direction eq "over" ? 1 : undef );
    }
    elsif ( $source_path->{item_type} eq 'meal'
        and $target_path->{item_type} eq 'dish' )
    {
        $c->detach( '/error/bad_request', [ { message => 'Cannot move meal on dish.' } ] );
    }
    elsif ( $source_path->{item_type} eq 'meal'
        and $target_path->{item_type} eq 'meal' )
    {
        if ( $moved->name eq $target->name ) {
            $c->detach(
                '/error/bad_request',
                [
                    {
                        message => 'Multiple meals with the same name and date are not allowed.',
                        code    => 'UNQMEAL',
                    }
                ]
            );
        }
        $moved->move_to_group( { project_id => $project->id, date => $target->date }, $target->position );
    }

    $moved = $moved->for_meals_dishes_editor;

    if ( $source_path->{item_type} eq 'dish' ) {
        $moved->{update_url} = $c->project_uri( $self->action_for('update_dish'), $moved->{id} )->as_string;
        $moved->{delete_url} = $c->project_uri( $self->action_for('delete_dish'), $moved->{id} )->as_string;
    }
    elsif ( $source_path->{item_type} eq 'meal' ) {
        $moved->{update_url} = $c->project_uri( $self->action_for('update_meal'), $moved->{id} )->as_string;
        $moved->{delete_url} = $c->project_uri( $self->action_for('delete_meal'), $moved->{id} )->as_string;
        $moved->{delete_dishes_url} =
          $c->project_uri( $self->action_for('delete_dishes_from_meal'), $moved->{id} )->as_string;
    }

    $c->stash->{ajax_response} = $moved;
}

sub delete_dishes_from_meal : POST Chained('/meal/base') PathPart('delete_dishes') Args(0)
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    $c->stash->{meal}->dishes->delete_update_items;

    $c->stash->{ajax_response} = { success => 1 };
}

=head2 Meal Management

=cut

sub create_meal : POST Chained('/project/base') PathPart('meals/create') Args(0)
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $meal = $c->project->create_related(
        meals => {
            date    => $c->req->body_data->{date},
            name    => $c->req->body_data->{name},
            comment => $c->req->body_data->{comment},
        }
    );

    $c->stash->{ajax_response} = { meal => $meal->for_meals_dishes_editor };
}

sub update_meal : POST Chained('/meal/base') PathPart('update') Args(0)
  RequiresCapability('edit_project') {
    my ( $self, $c, $id ) = @_;

    my $new_date = $c->req->body_data->{date}
      or $c->detach( '/error/bad_request', [ { message => "Missing 'date' property." } ] );

    try {
        $new_date = $c->project->parse_date($new_date);
    }
    catch ($error) {
        $c->detach( '/error/bad_request',
            [ { message => "Cannot parse 'date' property: invalid date string." } ] );
    };

    my $meal                 = $c->stash->{meal};
    my $other_meals          = $meal->other_meals;
    my $found_duplicate_meal = $other_meals->results_exist(
        {
            $other_meals->me('name') => $c->req->body_data->{name},
            $other_meals->me('date') => $meal->format_date($new_date),
        }
    );

    $found_duplicate_meal
      and $c->detach( '/error/bad_request',
        [ { message => "Cannot create meal with same name on same date." } ] );

    $meal->txn_do(
        sub {
            # TODO DBIx::Class::Ordered seems to have a bug which makes it
            # update the "group" and "position" columns but not any additional
            # columns. This leads to failing UNIQUE constraints when a name
            # is duplicate unless the "date" is changed in the same UPDATE.
            # Workaround: update in several steps.

            $meal->update( { name => '' } );          # expected not to exist
            $meal->update( { date => $new_date } );
            $meal->update(
                {
                    name    => $c->req->body_data->{name}    // $c->detach('/error/bad_request'),
                    comment => $c->req->body_data->{comment} // $c->detach('/error/bad_request'),
                }
            );
        }
    );

    $c->stash->{ajax_response} = $meal->for_meals_dishes_editor;
}

sub delete_meal : POST Chained('/meal/base') PathPart('delete') Args(0)
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    if ( $c->stash->{meal}->deletable ) {
        $c->stash->{meal}->delete;
    }
    else {
        $c->detach( '/error/bad_request',
            [ { message => $c->stash->{meal}->name . " cannot be deleted, because it contains dishes!" } ] );
    }

    $c->stash->{ajax_response} = { success => 1 };
}

=head2 Dish Management

=cut

sub create_dish : POST Chained('/project/base') PathPart('dishes/create') Args(0)
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $meal = $c->project->meals->find( $c->req->body_data->{meal_id} );

    my $dish_data = $c->req->body_data->{dish};

    my $dish = $meal->create_related(
        dishes => {
            servings           => $dish_data->{servings},
            name               => $dish_data->{name},
            description        => $dish_data->{description} // "",
            comment            => $dish_data->{comment}     // "",
            preparation        => $dish_data->{preparation} // "",
            prepare_at_meal_id => $dish_data->{prepare_at_meal} || undef,
        }
    );

    $c->stash->{ajax_response} = { dish => $dish->for_meals_dishes_editor };
}

sub create_dish_from_recipe : POST Chained('/project/base') PathPart('dishes/from_recipe') Args(0)
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $meal   = $c->project->meals->find( $c->req->body_data->{meal_id} );
    my $recipe = $c->project->recipes->find( $c->req->body_data->{recipe_id} );

    my $dish = $c->model('DB::Dish')->from_recipe(
        recipe   => $recipe,
        meal_id  => $meal->id,
        servings => $c->req->body_data->{servings},
        comment  => $c->req->body_data->{comment} // "",
    );

    $c->stash->{ajax_response} = {
        $dish->for_meals_dishes_editor->%*,
        delete_url => $c->project_uri( $self->action_for('delete_dish'), $dish->id )->as_string,
        update_url => $c->project_uri( $self->action_for('update_dish'), $dish->id )->as_string,
    };
}

sub update_dish : POST Chained('/dish/base') PathPart('update') Args(0)
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

            my $tags = $c->project->find_or_create_tags_from_names( $c->req->body_data->{tags} );
            $dish->set_tags( [ $tags->all ] );
        }
    );

    $c->stash->{ajax_response} = $dish->for_meals_dishes_editor;
}

sub delete_dish : POST Chained('/dish/base') PathPart('delete') Args(0)
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    $c->stash->{dish}->delete_update_items;

    $c->stash->{ajax_response} = { success => 1 };
}

__PACKAGE__->meta->make_immutable;

1;
