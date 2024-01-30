package Coocook::Controller::Ajax;

# ABSTRACT: base class for all controllers in Coocook

use Coocook::Base qw(Moose);

use Carp;

BEGIN { extends 'Catalyst::Controller' }

# TODO is this the best way to apply action roles?
sub COMPONENT {
    my ( $class, $app, $args ) = @_;

    $class->config(
        action_roles => [    #perltidy
            '~Ajax',
        ]
    );

    return $class->new( $app, $args );
}

__PACKAGE__->meta->make_immutable;

1;
