package Coocook::Controller::Ajax;

# ABSTRACT: base class for controllers that send & receive only JSON

use Coocook::Base qw(Moose);

BEGIN { extends 'Coocook::Controller' }

sub begin : Private {    # overrides Controller::Root->begin()
    my ( $self, $c ) = @_;

    $c->stash( current_view => 'JSON' );
}

sub end : ActionClass('RenderView') { }    # overrides Controller::Root->end()

__PACKAGE__->meta->make_immutable;

1;
