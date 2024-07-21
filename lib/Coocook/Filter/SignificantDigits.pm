package Coocook::Filter::SignificantDigits;

# ABSTRACT: TT filter module to display numbers with 3 most significant digits

use Coocook::Base;

use parent 'Template::Plugin::Filter';

use Scalar::Util 'looks_like_number';

# This plugin could be extended to support a custom number of digits for 3
# but this would require the plugin to be dynamic what makes TT load it
# over and over again for every filter call. Feature not required yet.

sub init ( $self, $config ) {
    $self->install_filter('significant_digits');
}

sub filter ( $self, $number ) {
    defined $number or return;
    length $number  or return "";

    $number =~ s/,/./g;    # workaround for German number format
    looks_like_number($number)
      or die "Argument \"$number\" isn't numeric";

    # TODO how to round to 3 significant digits while keeping decimal notation?

    # use 3 significant digits and format in decimal notation again
    my $str = sprintf '%f', sprintf '%.3g', $number;

    # trim trailing zeros after dot
    $str =~ s/
      (
        \.        # dot
        [0-9]*    # maybe some digits
        [1-9]     # last relevant digit
        \K        # don't include left part in match
      |       # OR
        \.        # dot directly before
      )
      0+          # only zeros anymore
      $
    //x;

    return $str;
}

1;
