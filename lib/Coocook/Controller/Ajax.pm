package Coocook::Controller::Ajax;

# ABSTRACT: base class for controllers that only handle Ajax requests

use Coocook::Base qw(Moose);

BEGIN { extends 'Coocook::Controller' }

sub begin : Private {    # overrides Controller::Root->begin()
    my ( $self, $c ) = @_;

    $c->stash( current_view => 'Ajax' );
}

sub end : ActionClass('RenderView') { }    # overrides Controller::Root->end()

__PACKAGE__->meta->make_immutable;

1;
