package Coocook::Util;

# ABSTRACT: helper functions (not methods) for Coocook, independent from Catalyst or any class

use Coocook::Base;

use Carp;
use Scalar::Util 'looks_like_number';

=head1 FUNCTIONS

=head2 significant_digits($number)

Returns a string for a given number with only 3 significant digits
and any remaining digits cut off.

=cut

sub significant_digits ($number) {
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

=head2 url_name($name)

Returns a name with unsafe characters replaced by C<-> but B<not> foldcased.
Most useful for building new URLs.

=cut

sub url_name ($name) {
    ( my $url_name = $name ) =~ s/\W+/-/g;

    return $url_name;
}

=head2 url_names_hashref($name)

Returns a hashref with C<url_name> and C<url_name_fc> keys
next to appropriate values. Useful for updating both rows in the database.

=cut

sub url_names_hashref ($name) {
    ( my $url_name = $name ) =~ s/\W+/-/g;

    return {
        url_name    => $url_name,
        url_name_fc => fc($url_name),
    };
}

=head2 username_valid($username)

Returns a boolean value indicating whether string C<$username>
is a valid username or organization name.

=cut

sub username_valid ($username) {
    return $username =~ m/ \A [0-9a-zA-Z_]+ \z /x;
}

1;
