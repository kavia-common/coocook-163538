package Coocook::Plugin::UriForStatic;

# ABSTRACT: Catalyst plugin for static URIs at CDN via $c->uri_for_static()

use Moose::Role;
use Carp;
use URI;

=head2 uri_for_static( $path, ... )

Supports same arguments as C<< $c->uri_for() >> but returns a URI
to the C<static/> directory in folder C<root> or, if
C<static_base_uri> is set in the app config, a C<$path> relative
from the configured base URI.

    $c->uri_for_static( '/some/file' ); # relative to static_base_uri or /static
    # http://.../static/some/file
    # or
    # http://static-base-uri/some/file

    # on page /user/profile
    $c->uri_for_static( 'avatar_generator.js' );
    # http://.../static/user/profile/avatar_generator.js
    # or
    # http://static-base-uri/user/profile/avatar_generator.js

=cut

# TODO support query parameter in config->static_base_uri

sub uri_for_static {
    my $c = shift;
    my ($path) = @_;

    # TODO relative paths not implemented yet
    ( ref($path) eq '' and $path =~ m{^/} )
      or croak "First argument must to uri_for_static must be string with absolute path, not '$_[0]'";

    if ( my $base_uri = $c->config->{static_base_uri} ) {

        # Catalyst->uri_for() as class method returns absolute path without host part
        my $path_uri = ( ref $c || $c )->uri_for(@_);
        $path_uri =~ s#^/## or die;

        return URI->new_abs( "$path_uri", $base_uri );
    }
    else {
        shift @_;
        return $c->uri_for( '/static' . $path, @_ );
    }
}

1;
