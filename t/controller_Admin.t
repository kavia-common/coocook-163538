use Test2::V0;

use lib 't/lib';
use Test::Coocook;

my @admin_pages = (
    '',
    qw(
      faq
      organizations
      projects
      recipes
      terms
      users
    )
);

plan tests => 2 + 3 * @admin_pages;

my $t = Test::Coocook->new;

my $anonymous_ua = $t->clone();

$t->get_ok('https://localhost/');
$t->login_ok( 'john_doe', 'P@ssw0rd' );

for my $page (@admin_pages) {
    my $path = '/admin/' . $page;

    $t->get_ok($path);

    $anonymous_ua->get_ok($path);
    $anonymous_ua->base_like(qr{/login\?redirect=});
}
