package Coocook::Controller::Meal;

use Moose;
use namespace::autoclean;

use Try::Tiny;

BEGIN { extends 'Coocook::Controller' }

=head1 NAME

Coocook::Controller::Meal - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub create : POST Chained('/project/base') PathPart('meals/create') Args(0) Does(~Ajax)
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $meal = $c->project->create_related(
        meals => {
            date    => $c->req->body_data->{date},
            name    => $c->req->body_data->{name},
            comment => $c->req->body_data->{comment},
        }
    );

    $c->stash->{json_data} = { meal => $meal->for_meals_dishes_editor };
}

sub base : Chained('/project/base') PathPart('meals') CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;

    $c->stash( meal => $c->project->meals->find($id) || $c->detach('/error/not_found') );
}

sub update : POST Chained('base') Does(~Ajax) Args(0) RequiresCapability('edit_project') {
    my ( $self, $c, $id ) = @_;
    my $new_date;
    try {
        $new_date = $c->req->body_data->{date};
    }
    catch {
        $c->res->status(400);
        $c->stash->{json_data} = {
            error => {
                message => "Invalid JSON body."
            }
        };
        return;
    };
    unless ($new_date) {
        $c->res->status(400);
        $c->stash->{json_data} = {
            error => {
                message => "Missing 'date' property."
            }
        };
        return;
    }
    try {
        $new_date = $c->project->parse_date($new_date);
    }
    catch {
        $c->res->status(400);
        $c->stash->{json_data} = {
            error => {
                message => "Cannot parse 'date' property: invalid date string."
            }
        };
        return;
    };

    if ( not $new_date->delta_days( $c->stash->{meal}->date )->is_zero ) {
        my $found_duplicate_meal = $c->project->meals->results_exist(
            {
                name => $c->req->body_data->{name},
                date => $new_date,
            }
        );
        if ($found_duplicate_meal) {
            $c->res->status(400);
            $c->stash->{json_data} = {
                error => {
                    message => "Cannot create meal with same name on same date."
                }
            };
            return;
        }
    }

    $c->stash->{meal}->update(
        {
            date    => $new_date,
            name    => $c->req->body_data->{name},
            comment => $c->req->body_data->{comment},
        }
    );
    $c->stash->{json_data} = $c->stash->{meal}->for_meals_dishes_editor;

}

sub delete : POST Chained('base') Does(~Ajax) Args(0) RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    if ( $c->stash->{meal}->deletable ) {
        $c->stash->{meal}->delete;
    }
    else {
        my $name = $c->stash->{meal}->name;
        $c->messages->error("$name cannot be deleted, because it contains dishes!");
        $c->stash->{json_data} = {
            error => {
                message => "$name cannot be deleted, because it contains dishes!"
            }
        };
        return;
    }

    $c->stash->{json_data} = { success => 1 };
}

sub delete_dishes : POST Chained('base') Does(~Ajax) Args(0) RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    $c->stash->{meal}->dishes->update_items_and_delete;

    $c->stash->{json_data} = { success => 1 };
}

sub redirect : Private {
    my ( $self, $c ) = @_;

    $c->response->redirect( $c->project_uri('/project/edit') );
}

__PACKAGE__->meta->make_immutable;

1;
