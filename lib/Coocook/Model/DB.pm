package Coocook::Model::DB;

# ABSTRACT: adaptor class to provide Coocook::Schema namespace in Coocook app

use Coocook::Base;
use Moose;
use namespace::autoclean;

extends 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->meta->make_immutable;

__PACKAGE__->config(
    connect_info => {
        sqlite_unicode => 1,
    },
    schema_class => 'Coocook::Schema',
);

sub statistics ( $self, @args ) { $self->schema->statistics(@args) }

1;
