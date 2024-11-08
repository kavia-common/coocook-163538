package Coocook::Filter::SignificantDigits;

# ABSTRACT: TT filter module to display numbers with 3 most significant digits

use Coocook::Base;

use parent 'Template::Plugin::Filter';

use Coocook::Util;

# This plugin could be extended to support a custom number of digits for 3
# but this would require the plugin to be dynamic what makes TT load it
# over and over again for every filter call. Feature not required yet.

sub init ( $self, $config ) {
    $self->install_filter('significant_digits');
}

sub filter ( $self, $number ) {
    return Coocook::Util::significant_digits($number);
}

1;
