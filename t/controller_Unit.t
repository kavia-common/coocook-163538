use Test2::V0;

use lib 't/lib';
use Test::Coocook;

plan(5);

my $t = Test::Coocook->new();

$t->get_ok('https://localhost/project/1/Test-Project/units');
$t->text_contains(
        "1\N{THIN SPACE}g = 0.001\N{THIN SPACE}kg  |  1\N{THIN SPACE}kg = 1000\N{THIN SPACE}g"
      . "delete_forever" );

# make sure 1:1 conversions are displayed only once
$t->text_contains( "btl (bottles) 1\N{THIN SPACE}btl = 1\N{THIN SPACE}pcs" . "delete_forever" );
$t->text_contains( "pcs (pieces) 1\N{THIN SPACE}pcs = 1\N{THIN SPACE}btl" . "delete_forever" );

$t->content_contains('https://localhost/project/1/Test-Project/unit/1');
