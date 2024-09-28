use Coocook::Base;

use Template;
use Test2::V0 -no_warnings => 1;
use Test::Builder;

plan(16);

my $tt = Template->new( PLUGIN_BASE => 'Coocook::Filter' );

like dies { t( q('foo') => '' ) }, qr/isn't numeric/, "exception for non-numeric string";
t( q('')                 => '', "empty string" );
t( q(undefined_variable) => '', "undef becomes empty string" );

is Coocook::Filter::NumberSuffix->filter(undef) => undef, "... filter(undef) returns undef";
is Coocook::Filter::NumberSuffix->filter(12345) => "12.3K";    # just to prove test syntax above

t( 1          => "1" );
t( 1.23456789 => "1.23456789" );
t( 12.3456789 => "12.3456789" );
t( 123.456789 => "123.456789" );
t( 1234.56789 => "1.23K" );
t( 12345.6789 => "12.3K" );
t( 123456.789 => "123K" );
t( 1234567.89 => "1.23M" );
t( 12345678.9 => "12.3M" );
t( 123456789  => "123M" );
t( 1234567890 => "1234M" );

sub t ( $input, $expected, $name = "$input = '$expected'" ) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $tt->process( \<<~TT, {}, \my $output ) or die $tt->error;
    [% USE NumberSuffix;
    $input | number_suffix ~%]
    TT

    is $output => $expected, $name;
}
