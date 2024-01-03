package Coocook::View::HTML::Snippet;

# ABSTRACT: a clone of View::HTML without wrapper for sending smaller HTML parts

use Coocook::Base;

use parent 'Coocook::View::HTML';

__PACKAGE__->config( WRAPPER => undef );

1;
