package Coocook::View::Ajax;

# ABSTRACT: view for Coocook to create Ajax responses, currently only in JSON

use Coocook::Base qw( Moose MooseX::NonMoose );

extends 'Catalyst::View::JSON';

__PACKAGE__->meta->make_immutable;

# not named "stash" because it's not based on key names like $c->stash
# and it might be an arrayref or hashref
__PACKAGE__->config( expose_stash => 'ajax_response' );

# override to allow sending empty response
sub render ( $self, $c, $data ) {
    if ( not defined $data ) {
        $c->res->headers->remove_header('Content-Type');
        return '';
    }

    return $self->json_dumper->( $data, $self, $c );    # copied from upstream;
}

1;
