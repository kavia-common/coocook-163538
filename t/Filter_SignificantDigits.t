use Coocook::Base;

use Template;
use Test2::V0 -no_warnings => 1;
use Test::Builder;

plan(15);

my $tt = Template->new( PLUGIN_BASE => 'Coocook::Filter' );

like dies { t( q('foo') => '' ) }, qr/isn't numeric/, "exception for non-numeric string";
t( q('')                 => '', "empty string" );
t( q(undefined_variable) => '', "undef becomes empty string" );

is Coocook::Filter::SignificantDigits->filter(undef) => undef, "... filter(undef) returns undef";
is Coocook::Filter::SignificantDigits->filter(12345) => "12300";   # just to prove test syntax above

# 3 significant digits
t( 123        => "123" );
t( 1.23       => "1.23" );
t( 1.234567   => "1.23" );
t( 12345.6789 => "12300" );
t( 1 / 3      => "0.333" );
t( 0.999999   => "1" );
t( 123456789  => "123000000" );
t( 0.0101     => "0.0101" );
t( '0.000001' => "0.000001" );

todo 'sprintf("%f") cuts digits off this string--how to fix that?' => sub {
    t( '0.0000012345' => "0.00000123" );
};

sub t ( $input, $expected, $name = "$input = '$expected'" ) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $tt->process( \<<~TT, {}, \my $output ) or die $tt->error;
    [% USE SignificantDigits;
    $input | significant_digits ~%]
    TT

    is $output => $expected, $name;
}
