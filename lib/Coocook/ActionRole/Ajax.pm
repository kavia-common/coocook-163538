package Coocook::ActionRole::Ajax;

# ABSTRACT: role for controller actions that respond with JSON and require a Session

use Coocook::Base;
use Moose::Role;
use namespace::autoclean;

before execute => sub ( $self, $controller, $c ) {
    $c->stash( current_view => 'JSON' );
};

1;
