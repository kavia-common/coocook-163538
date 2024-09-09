package Coocook::ActionRole::RequiresCapability;

# ABSTRACT: role for controller action to assert Model::Authz grants capability

use Coocook::Base qw(Moose::Role);

use Coocook::Model::Authorization;

around execute => sub {
    my $orig = shift;
    my $self = shift;
    my ( $controller, $c ) = @_;

    if ( my $capabilities = $self->attributes->{RequiresCapability} ) {
        $c->require_capability( $_, $c->stash ) for @$capabilities;
    }

    $self->$orig(@_);
};

1;
