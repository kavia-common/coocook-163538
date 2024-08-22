package Coocook::Controller::Meal;

use Coocook::Base qw(Moose);

BEGIN { extends 'Coocook::Controller' }

=head1 NAME

Coocook::Controller::Meal - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub base : Chained('/project/base') PathPart('meals') CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;

    $c->stash( meal => $c->project->meals->find($id) || $c->detach('/error/not_found') );
}

# this controller is currently nearly empty except for the base() method
# but that is used by chained actions in Controller::Ajax::MealsDishesEditor

__PACKAGE__->meta->make_immutable;

1;
