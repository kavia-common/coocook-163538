use Test2::V0;
use experimental qw(signatures);

use Coocook::Filter::NumberSuffix;
use Test::Builder;
use Test2::API qw(context);

plan(16);

ok my $filter = Coocook::Filter::NumberSuffix->new();

isa_ok $filter, 'Template::Plugin::Filter';

like dies { $filter->filter("foo") }, qr/isn't numeric/, "exception for non-numeric string";

t( undef() => undef, "undef" );
t( ""      => "",    "empty string" );

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

    my $output = $filter->filter($input);

    is $output => $expected, $name;
}
