use Test2::V0;

use lib 't/lib';
use Test::Coocook;

plan(2);

my $t = Test::Coocook->new();

$t->get_ok('https://localhost/project/1/Test-Project/recipes');
$t->content_contains('https://localhost/project/1/Test-Project/tag/3');
