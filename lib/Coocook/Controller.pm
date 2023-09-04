package Coocook::Controller;

# ABSTRACT: base class for all controllers in Coocook

use Moose;
use experimental qw(signatures);
use namespace::autoclean;

use Carp;

BEGIN { extends 'Catalyst::Controller' }

# TODO is this the best way to apply action roles?
sub COMPONENT ( $class, $app, $args ) {
    $class->config(
        action_roles => [    #perltidy
            '~RequiresCapability',
        ]
    );

    return $class->new( $app, $args );
}

around action_for => sub ( $orig, $self, $action_name ) {
    my $action = $self->$orig($action_name)
      or croak "No such action: $action_name";

    return $action;
};

__PACKAGE__->meta->make_immutable;

1;
