package Coocook::Controller;

# ABSTRACT: base class for all controllers in Coocook

use Coocook::Base qw(Moose);

use Carp;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config( action_roles => ['~RequiresCapability'] );

around action_for => sub ( $orig, $self, $action_name ) {
    my $action = $self->$orig($action_name)
      or croak "No such action: $action_name";

    return $action;
};

__PACKAGE__->meta->make_immutable;

1;
