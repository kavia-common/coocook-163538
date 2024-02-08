package Coocook::Controller::Ajax;

# ABSTRACT: base class for all controllers in Coocook

use Coocook::Base qw(Moose);

use Carp;

BEGIN { extends 'Coocook::Controller' }

# TODO is this the best way to apply action roles?
sub COMPONENT {
    my ( $class, $app, $args ) = @_;

    $class->config(
        action_roles => [
            '~Ajax',
            '~RequiresCapability',    # TODO this should be inherited from Coocook::Controller
        ]
    );

    return $class->new( $app, $args );
}

__PACKAGE__->meta->make_immutable;

1;
