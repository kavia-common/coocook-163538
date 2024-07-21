package Coocook::Controller::API;

use Coocook::Base qw(Moose);

# BEGIN-block necessary to make method attributes work
BEGIN { extends 'Coocook::Controller' }

sub base : Chained('/') PathPart('api') CaptureArgs(0) {
    my ( $self, $c ) = @_;

    $c->stash( current_view => 'Ajax' );
}

sub statistics : GET HEAD Chained('base') Args(0) Public {
    my ( $self, $c ) = @_;

    $c->stash( ajax_response => $c->model('DB')->statistics );
}

sub end : ActionClass('RenderView') { }    # Overrides Controller::Root->end

__PACKAGE__->meta->make_immutable;

1;
