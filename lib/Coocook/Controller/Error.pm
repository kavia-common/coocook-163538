package Coocook::Controller::Error;

use Coocook::Base qw(Moose);

use Carp;

BEGIN { extends 'Coocook::Controller' }

our $ENABLE_INTERNAL_SERVER_ERROR_PAGE //= $ENV{COOCOOK_ENABLE_INTERNAL_SERVER_ERROR_PAGE};

sub bad_request : Private {
    my ( $self, $c, $error ) = @_;

    $c->response->status(400);

    if ( ( $c->stash->{current_view} // '' ) eq 'Ajax' ) {
        $error and $c->stash( ajax_response => { error => $error } );
    }
    else {
        $error
          and $c->messages->error($error);

        $c->stash(
            template => 'error/bad_request.tt',    # set explicitly to allow $c->detach('/error/bad_request')
            method   => $c->req->method,
        );
    }
}

sub forbidden : Private {
    my ( $self, $c, $error ) = @_;

    $error
      and $c->messages->error($error);

    $c->response->status(403);

    $c->stash(
        template => 'error/forbidden.tt',    # set explicitly to allow $c->detach('/error/forbidden')
        method   => $c->req->method,
    );
}

=head2 internal_server_error

An endpoint to receive an HTML page which can be saved and displayed as static 500 error page by a proxy.

=cut

sub internal_server_error : HEAD GET Chained('/base') Public {
    my ( $self, $c ) = @_;

    $ENABLE_INTERNAL_SERVER_ERROR_PAGE
      or $c->detach( $self->action_for('page_not_found') );

    # do NOT set status to 500 because this request actually works

    $c->stash->{canonical_url} = undef;    # can't have dynamic URL in static HTML file
    $c->stash->{robots}->index(0);         # hide this in search engines
}

=head2 page_not_found

=head2 project_not_found

=head2 object_not_found

Standard 404 error pages for different types of objects.

=cut

sub page_not_found : AnyMethod Chained('/base') PathPart('') Public {
    my ( $self, $c ) = @_;
    $c->detach( $self->action_for('not_found'), ['page'] );
}

sub object_not_found : Private {
    my ( $self, $c ) = @_;
    $c->detach( $self->action_for('not_found'), ['object'] );
}

sub project_not_found : Private {
    my ( $self, $c ) = @_;
    $c->detach( $self->action_for('not_found'), ['project'] );
}

sub not_found : Private {
    my ( $self, $c, $object_type ) = @_;

    $c->response->status(404);

    $c->stash(
        canonical_url => undef,
        object_type   => $object_type || croak("Object type not defined"),
        template      => 'error/not_found.tt', # set explicitly to allow $c->detach('/error/page_not_found')
    );
}

__PACKAGE__->meta->make_immutable;

1;
