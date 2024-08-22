package Coocook::ActionRole::Ajax;

# ABSTRACT: role for controller actions that handle Ajax requests and require a Session

use Coocook::Base qw(Moose::Role);

before execute => sub ( $self, $controller, $c, @args ) {
    $c->stash( current_view => 'Ajax' );
};

1;
