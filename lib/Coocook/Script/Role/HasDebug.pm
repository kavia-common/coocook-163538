package Coocook::Script::Role::HasDebug;

use Coocook::Base qw(Moose::Role);

has debug => (
    is            => 'rw',
    isa           => 'Bool',
    documentation => "enable debugging output",
);

1;
