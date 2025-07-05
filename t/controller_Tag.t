use Test2::V0;

use lib 't/lib';
use Test::Coocook;

plan(8);

my $t = Test::Coocook->new();

$t->get_ok('https://localhost/project/1/Test-Project/tag/1');
$t->text_contains('Tag gluten');
$t->text_contains('Tag Group: allergens');
$t->content_contains('https://localhost/project/1/Test-Project/article/1');

$t->get_ok('https://localhost/project/1/Test-Project/tag/3');
$t->text_contains('No Tag Group.');
$t->content_contains('https://localhost/project/1/Test-Project/recipe/1');
$t->content_contains('https://localhost/project/1/Test-Project/dish/1');
