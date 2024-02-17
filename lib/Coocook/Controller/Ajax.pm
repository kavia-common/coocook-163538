package Coocook::Controller::Ajax;

# ABSTRACT: base class for controllers that send & receive only JSON

use Coocook::Base qw(Moose);

BEGIN { extends 'Coocook::Controller' }

__PACKAGE__->config( '+action_roles' => ['~Ajax'] );

# DO NOT PLACE ENDPOINT METHODS HERE
# because other controller directly
# inherit from this class.
#
# If this controller should ever hold
# endpoint methods, change inheritance
# to a seperate common base class.

__PACKAGE__->meta->make_immutable;

1;
