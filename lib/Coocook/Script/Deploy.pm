package Coocook::Script::Deploy;

# ABSTRACT: script for database maintenance based on App::DH

use Coocook::Base;
use Moose;
use namespace::autoclean;

use Coocook::DeploymentHandler;
use PerlX::Maybe;

extends 'App::DH';

has '+schema' => ( default => 'Coocook::Schema' );

sub _build_database { [qw< SQLite PostgreSQL >] }

sub _build__dh ($self) {    # copy from App::DH
    return Coocook::DeploymentHandler->new(    # adjusted to custom class
        {
            schema           => $self->_schema,
            force_overwrite  => $self->force,
            script_directory => $self->script_dir,
            databases        => $self->database,
            maybe to_version => $self->target,
        },
    );
}

__PACKAGE__->meta->make_immutable;

1;
