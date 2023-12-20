package Coocook::Controller::Project;

use DateTime;
use Moose;
use namespace::autoclean;
use JSON::MaybeXS qw/to_json/;

BEGIN { extends 'Coocook::Controller' }

=head1 NAME

Coocook::Controller::Project - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub fallback_old_url_scheme : Chained('/base') PathPart('project')
  Args GET HEAD Public {    # TODO deprecated
    my ( $self, $c ) = @_;

    if ( $c->req->method eq 'GET' or $c->req->method eq 'POST' ) {
        my $args = $c->req->args;

        if ( @$args >= 1 ) {
            my ($url_name) = @$args;

            if ( my $project = $c->model('DB::Project')->find_by_url_name($url_name) ) {
                $args->[0] = $project->url_name;    # might change lower/upper case
                unshift @$args, $project->id;

                my $uri = $c->uri_for( '/project', @$args );
                $uri->query( $c->req->uri->query );

                $c->redirect_detach( $uri, 301 );
            }
        }
    }

    $c->detach('/error/not_found');
}

=head2 id_only

URL shortcut that catches C</project/42> without a 2nd path argument.

=cut

sub id_only : GET HEAD Chained('/base') PathPart('project') Args(1) CustomAuthz {
    my ( $self, $c, $id ) = @_;

    $c->go( show => [ $id, '' ], [] );    # permission checks happen there
}

=head2 base

Chain action that captures the project ID and stores the
C<Result::Project> object in the stash.

=cut

sub base : Chained('/base') PathPart('project') CaptureArgs(2) {
    my ( $self, $c, $id, $url_name ) = @_;

    $id =~ m/[^0-9]/
      and $c->detach('fallback_old_url_scheme');    # TODO deprecated

    my $project = $c->model('DB::Project')->find( { id => $id } )
      or $c->detach('/error/not_found');

    $c->stash( project => $project );

    $c->redirect_canonical_case( 1 => $project->url_name );

    $project->is_public
      or $c->stash->{robots}->index(0);

    $c->stash(
        project_urls => {
            project          => $c->project_uri('/project/show'),
            edit             => $c->project_uri('/project/edit'),
            recipes          => $c->project_uri('/recipe/index'),
            articles         => $c->project_uri('/article/index'),
            tags             => $c->project_uri('/tag/index'),
            unassigned_items => $c->project_uri('/item/unassigned'),
            purchase_lists   => $c->project_uri('/purchase_list/index'),
            shop_sections    => $c->project_uri('/shop_section/index'),
            units            => $c->project_uri('/unit/index'),
            archive          => $c->project_uri('/project/archive'),
            unarchive        => $c->project_uri('/project/unarchive'),
        },
    );

    if ( $c->request->method eq "GET" or $c->request->method eq "HEAD" ) {
        my $importer  = $c->model('ProjectImporter');
        my $inventory = $c->project->inventory;

        $c->stash( inventory => $inventory );

        $c->stash->{project_urls}{import} =
            $importer->importable_properties($inventory) > 0
          ? $c->project_uri('/project/get_import')
          : undef;
    }
}

sub submenu : Chained('base') PathPart('') CaptureArgs(0) {
    my ( $self, $c ) = @_;

    $c->stash(
        submenu_items => [
            { text => "Show project",   action => 'project/show' },
            { text => "Meals & Dishes", action => 'project/edit' },
            { text => "Permissions",    action => 'permission/index' },
            { text => "Settings",       action => 'project/settings' },
        ],
    );
}

sub show : GET HEAD Chained('submenu') PathPart('') Args(0) RequiresCapability('view_project') {
    my ( $self, $c ) = @_;

    my $days = $c->model('Plan')->project( $c->project );

    for my $day (@$days) {
        for my $meal ( $day->{meals}->@* ) {
            for my $dish ( $meal->{dishes}->@* ) {
                $dish->{url} = $c->project_uri( '/dish/edit', $dish->{id} );
            }
        }

        my $date = $day->{date};
        $day->{url} = $c->project_uri( '/print/day', $date->year, $date->month, $date->day );
    }

    $c->stash(
        can_edit      => !!$c->has_capability('edit_project'),
        can_unarchive => !!$c->has_capability('unarchive_project'),
        days          => $days,
    );
}

sub edit : GET HEAD Chained('submenu') PathPart('edit') Args(0) RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $default_date = DateTime->today;

    my $days = $c->model('Plan')->project_for_meals_dishes_editor( $c->project );

    for my $day ( keys %$days ) {
        for my $meal_key ( keys $days->{$day}->%* ) {
            my $meal = $days->{$day}->{$meal_key};
            $meal->{delete_dishes_url} = $c->project_uri( '/meal/delete_dishes', $meal->{id} )->as_string;
            $meal->{delete_url}        = $c->project_uri( '/meal/delete',        $meal->{id} )->as_string;
            $meal->{update_url}        = $c->project_uri( '/meal/update',        $meal->{id} )->as_string;
            for my $dish_key ( keys $meal->{dishes}->%* ) {
                my $dish = $meal->{dishes}->{$dish_key};
                $dish->{delete_url} = $c->project_uri( '/dish/delete_ajax', $dish->{id} )->as_string;
                $dish->{update_url} = $c->project_uri( '/dish/update_ajax', $dish->{id} )->as_string;
            }
        }
    }

    $c->stash(
        meals_dishes_editor_json => to_json(
            {
                projectPlan       => $days,
                projectId         => $c->project->id,
                projectName       => $c->project->name,
                recipes           => [ $c->project->recipes->sorted->hri->all ],
                getProjectPlanURL => $c->project_uri('/project/get_project_plan_ajax')->as_string,
                getAllRecipesURL  => $c->project_uri('/recipe/get_all_ajax')->as_string,
                moveMealDishURL   => $c->project_uri('/project/move_meal_or_dish_ajax')->as_string,
                createMealURL     => $c->project_uri('/meal/create')->as_string,
                createDishURL     => $c->project_uri('/dish/create')->as_string,
                dishFromRecipeURL => $c->project_uri('/dish/from_recipe')->as_string,
            }
        ),
    );
}

sub get_project_plan_ajax : GET HEAD Chained('submenu') PathPart('project_plan') Args(0)
  RequiresCapability('view_project') Does(~Ajax) {
    my ( $self, $c ) = @_;

    my $days = $c->model('Plan')->project_for_meals_dishes_editor( $c->project );

    for my $day ( keys %$days ) {
        for my $meal_key ( keys $days->{$day}->%* ) {
            my $meal = $days->{$day}->{$meal_key};
            $meal->{delete_dishes_url} = $c->project_uri( '/meal/delete_dishes', $meal->{id} )->as_string;
            $meal->{delete_url}        = $c->project_uri( '/meal/delete',        $meal->{id} )->as_string;
            $meal->{update_url}        = $c->project_uri( '/meal/update',        $meal->{id} )->as_string;
            for my $dish_key ( keys $meal->{dishes}->%* ) {
                my $dish = $meal->{dishes}->{$dish_key};
                $dish->{delete_url} = $c->project_uri( '/dish/delete_ajax', $dish->{id} )->as_string;
                $dish->{update_url} = $c->project_uri( '/dish/update_ajax', $dish->{id} )->as_string;
            }
        }
    }

    $c->stash->{json_data} = {
        project_plan         => $days,
        get_project_plan_url => $c->project_uri('/project/get_project_plan_ajax')->as_string,
        move_meal_dish_url   => $c->project_uri('/project/move_meal_or_dish_ajax')->as_string,
    };
}

=head2 move_meal_or_dish_ajax()

Move a Meal before or after another Meal or move a Dish to another Meal or before or after
another Dish.

=head3 Errors

=over 4

=item UNQMEAL
The name of a meal should be unique per day. For this reason, this method throws an error when it tries
to move a meal with a name which already exists on the target date.

=back

=cut

sub move_meal_or_dish_ajax : POST Chained('submenu') PathPart('move_meal_dish') Args(0) Does(~Ajax)
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $project = $c->project;

    my $source_path = $c->req->body_data->{source_path};
    my $target_path = $c->req->body_data->{target_path};
    my $direction   = $c->req->body_data->{direction};

    my $plan = $c->model('Plan');

    my $moved = $plan->resolve_meal_dish_path( $project, $source_path );
    return $c->stash->{json_data} = { error => { message => 'Invalid source_path' } }
      unless ( defined $moved );

    my $target = $plan->resolve_meal_dish_path( $project, $target_path );
    return $c->stash->{json_data} = { error => { message => 'Invalid target_path' } }
      unless ( defined $target );

    if (   $source_path->{item_type} eq 'dish'
        && $target_path->{item_type} eq 'dish' )
    {
        $moved->move_to_group( { meal_id => $target->meal->id }, $target->position );
    }
    elsif ($source_path->{item_type} eq 'dish'
        && $target_path->{item_type} eq 'meal' )
    {
        $moved->move_to_group( { meal_id => $target->id }, $direction eq "over" ? 1 : undef );
    }
    elsif ($source_path->{item_type} eq 'meal'
        && $target_path->{item_type} eq 'dish' )
    {
        $c->stash->{json_data} =
          { error => { message => 'Cannot move meal on dish.' } };
        return;
    }
    elsif ($source_path->{item_type} eq 'meal'
        && $target_path->{item_type} eq 'meal' )
    {
        if ( $moved->name eq $target->name ) {
            $c->stash->{json_data} = {
                error => {
                    message => 'Multiple meals with the same name and date are not allowed.',
                    code    => 'UNQMEAL'
                }
            };
            $c->response->status(400);
            return;
        }
        $moved->move_to_group( { project_id => $project->id, date => $target->date }, $target->position );
    }

    $moved = $moved->for_meals_dishes_editor;
    if ( $source_path->{item_type} eq 'dish' ) {
        $moved->{delete_url} =
          $c->project_uri( '/dish/delete_ajax', $moved->{id} )->as_string;
        $moved->{update_url} =
          $c->project_uri( '/dish/update_ajax', $moved->{id} )->as_string;
    }
    elsif ( $source_path->{item_type} eq 'meal' ) {
        $moved->{delete_dishes_url} =
          $c->project_uri( '/meal/delete_dishes', $moved->{id} )->as_string;
        $moved->{delete_url} =
          $c->project_uri( '/meal/delete', $moved->{id} )->as_string;
        $moved->{update_url} =
          $c->project_uri( '/meal/update', $moved->{id} )->as_string;
    }
    $c->stash->{json_data} = $moved;
}

sub settings : GET HEAD Chained('submenu') PathPart('settings') Args(0)
  RequiresCapability('view_project_settings') {
    my ( $self, $c ) = @_;

    $c->stash(
        update_url     => $c->project_uri('/project/update'),
        rename_url     => $c->project_uri('/project/rename'),
        visibility_url => $c->project_uri('/project/visibility'),
        delete_url     => $c->project_uri('/project/delete'),
    );
}

sub exportable_projects : Private {
    my ( $self, $c ) = @_;

    return [ grep { $c->has_capability( export_from_project => { source_project => $_ } ) }
          $c->project->other_projects->sorted->all ];
}

sub get_import : GET HEAD Chained('base') PathPart('import') Args(0)
  RequiresCapability('import_into_project') {    # import() already used by 'use'
    my ( $self, $c ) = @_;

    my $importer = $c->model('ProjectImporter');

    my $inventory  = $c->project->inventory;
    my $properties = $importer->properties;
    my %properties = map { $_->{key} => $_ } @$properties;

    for my $property ( $importer->unimportable_properties($inventory) ) {
        $properties{ $property->{key} }->{disabled} = 1;
    }

    $c->stash(
        projects        => $c->forward('exportable_projects'),
        properties      => $properties,
        properties_json => $importer->properties_json,
        import_url      => $c->project_uri('/project/post_import'),
        template        => 'project/import.tt',
    );
}

sub post_import : POST Chained('base') PathPart('import') Args(0)
  RequiresCapability('import_into_project') {    # import() already used by 'use'
    my ( $self, $c ) = @_;

    my $importer = $c->model('ProjectImporter');

    my $source = $c->model('DB::Project')->find( $c->req->params->get('source_project') )
      or $c->detach('/error/bad_request');

    my $target = $c->project;

    $c->require_capability( export_from_project => { source_project => $source } );

    # extract properties selected in form
    my @properties =
      grep { my $key = $_->{key}; $c->req->params->get("property_$key") } $importer->properties->@*;

    my $ok =
      $importer->can_import_properties( $target, [ map { $_->{key} } @properties ], \my @errors );

    if ( not $ok ) {
        $c->messages->error($_) for @errors;
        $c->redirect_detach( $c->project_uri( $c->action ) );
    }

    $importer->import_data( $source => $target, [ map { $_->{key} } @properties ] );

    $c->messages->info( "Successfully imported " . join ", ", map { $_->{name} } @properties );

    $c->detach( redirect => [$target] );
}

sub create : POST Chained('/base') PathPart('project/create') Args(0)
  RequiresCapability('create_project') {
    my ( $self, $c ) = @_;

    my $name = $c->req->params->get('name');

    length $name > 0
      or $c->detach( '/error/bad_request', ["Cannot create project with empty name!"] );

    my $is_public = !!$c->req->params->get('is_public');

    # TODO keep form input
    if ( not( $is_public or $c->has_capability('create_private_project') ) ) {
        $c->messages->error("You're not allowed to create private projects");
        $c->detach('/error/forbidden');
    }

    my $projects = $c->model('DB::Project');

    my $project = $c->stash->{project} = $c->model('DB::Project')->new_result(
        {
            name           => $c->req->params->get('name'),
            description    => '',
            owner_id       => $c->user->id,
            is_public      => $projects->format_bool($is_public),
            projects_users => [    # relationship automatically triggers transaction
                {
                    user_id => $c->user->id,
                    role    => 'owner',
                }
            ],
        }
    );

    # TODO keep form input
    if ( $projects->search( { url_name_fc => $project->url_name_fc } )->results_exist ) {
        $c->messages->error("Project name is already in use");
        $c->redirect_detach( $c->uri_for('/') );
    }

    $project->insert();

    my $exportable_projects = $c->forward('exportable_projects');

    $c->response->redirect(
        $c->project_uri( $self->action_for( @$exportable_projects > 0 ? 'get_import' : 'show' ) ) );
}

sub update : POST Chained('base') Args(0) RequiresCapability('update_project') {
    my ( $self, $c ) = @_;

    $c->project->update(
        { description => $c->req->params->get('description') // $c->detach('/error/bad_request') } );

    $c->response->redirect( $c->project_uri('/project/settings') );
}

sub archive : POST Chained('base') Args(0) RequiresCapability('archive_project') {
    my ( $self, $c ) = @_;

    $c->project->archive();

    $c->response->redirect( $c->project_uri('/project/show') );
}

sub unarchive : POST Chained('base') Args(0) RequiresCapability('unarchive_project') {
    my ( $self, $c ) = @_;

    $c->project->unarchive();

    $c->response->redirect( $c->project_uri('/project/show') );
}

sub rename : POST Chained('base') Args(0) RequiresCapability('rename_project') {
    my ( $self, $c ) = @_;

    $c->project->update( { name => $c->req->params->get('name') // $c->detach('/error/bad_request') } );

    $c->response->redirect( $c->project_uri('/project/settings') );
}

sub visibility : POST Chained('base') Args(0) RequiresCapability('edit_project_visibility') {
    my ( $self, $c ) = @_;

    $c->project->update(
        { is_public => $c->project->format_bool( !!$c->req->params->get('public') ) } );

    $c->response->redirect( $c->project_uri('/project/settings') );
}

sub delete : POST Chained('base') Args(0) RequiresCapability('delete_project') {
    my ( $self, $c ) = @_;

    if ( $c->req->params->get('confirmation') eq $c->project->name ) {
        $c->project->txn_do(
            sub {
                $c->model('DB')->schema->pgsql_set_constraints_deferred();
                $c->project->delete;
            }
        );
        $c->messages->info( sprintf "Project '%s' has been deleted.", $c->project->name );
        $c->response->redirect( $c->uri_for_action('/index') );
    }
    else {
        $c->messages->warn("Project is not deleted without confirmation!");
        $c->response->redirect( $c->project_uri('/project/settings') );
    }
}

sub redirect : Private {
    my ( $self, $c, $project ) = @_;

    $c->response->redirect(
        $c->uri_for_action( $self->action_for('show'), [ $project->id, $project->url_name ] ) );
}

__PACKAGE__->meta->make_immutable;

1;
