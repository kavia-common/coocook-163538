package Coocook::Filter::NumberSuffix;

# ABSTRACT: TT filter module to display numbers with 3 most significant digits

use Coocook::Base;

use parent 'Template::Plugin::Filter';

use Coocook::Filter::SignificantDigits;
use Scalar::Util 'looks_like_number';

sub init ( $self, $config ) {
    $self->install_filter('number_suffix');
}

sub filter ( $self, $number ) {
    defined $number or return;
    length $number  or return "";

    $number =~ s/,/./g;    # workaround for German number format
    looks_like_number($number)
      or die "Argument \"$number\" isn't numeric";

    if ( $number < 1000 ) { return $number }

    my $suffix   = '';
    my @suffixes = qw( K M );

    while (@suffixes) {
        $number /= 1000;
        $suffix  = shift @suffixes;

        if ( $number < 1000 ) {
            return Coocook::Filter::SignificantDigits->filter($number) . $suffix;
        }
    }

    return int($number) . $suffix;
}

1;
