package Coocook::View::JSON;

# ABSTRACT: view for Coocook to create JSON responses

use Coocook::Base qw( Moose MooseX::NonMoose );

extends 'Catalyst::View::JSON';

__PACKAGE__->meta->make_immutable;

__PACKAGE__->config( expose_stash => 'json_data' );

# override to allow sending empty response
sub render ( $self, $c, $data ) {
    if ( not defined $data ) {
        $c->res->headers->remove_header('Content-Type');
        return '';
    }

    return $self->json_dumper->( $data, $self, $c );    # copied from upstream;
}

1;
