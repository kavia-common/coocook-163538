use Test2::V0;

use lib 't/lib';
use Test::Coocook;

plan(14);

my $t = Test::Coocook->new();

$t->get('https://localhost/');
$t->login_ok( 'john_doe', 'P@ssw0rd' );

$t->follow_link_ok( { text => 'public Test Project' } );
$t->follow_link_ok( { text => 'Articles' } );
$t->content_contains('https://localhost/project/1/Test-Project/tag/1');

$t->follow_link_ok( { text => 'add New article' } );

$t->submit_form_ok( { with_fields => { name => 'aether' } }, "create article" );

is $t->schema->resultset('Article')->find( { name => 'aether' } )->units->count => 0,
  "... new article has no units";

$t->follow_link_ok( { text => 'Articles' } );

$t->text_contains('aether');

$t->follow_link_ok( { text => 'cheese' } );

my $update_req;

subtest "invalid unit IDs" => sub {
    my $res = $t->submit_form_fails( { with_fields => { units => 9999 }, strict_forms => 0 } );
    $t->text_contains('invalid');

    $update_req = $res->request;
};

$t->back();

# select unit 3 (liters), I couldn't get this working by passing units=>[...] to submit_form()
$t->form_number(3);
$t->tick( units => 3 );

$t->submit_form_ok( { with_fields => { name => 'cheddar' } }, "update article" );

$t->text_contains('cheddar');

is
  join( ',' =>
      sort $t->schema->resultset('Article')->find( { name => 'cheddar' } )
      ->units->get_column('short_name')->all ) => 'g,kg,l';
