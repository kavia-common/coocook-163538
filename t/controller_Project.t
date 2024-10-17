use Test2::V0;

use DateTime;
use Test::Builder;

use lib 't/lib';
use Test::Coocook;

plan(39);

my $t = Test::Coocook->new();
$t->schema->resultset('User')->find( { name_fc => 'other' } )->update( { password => 'P@ssw0rd' } );

subtest "project not found" => sub {
    ok $t->get('https://localhost/project/999/foobar');
    $t->status_is(404);
};

# TODO deprecated: remove fallback and UNIQUE constraint on projects.name[_fc]
subtest "deprecated: fallback redirects from old URL scheme" => sub {
    $t->redirect_is(
        'https://localhost/project/Test-Project/foo?bar=baz' =>
          "https://localhost/project/1/Test-Project/foo?bar=baz",
        301    # permanent
    );

    $t->redirect_is(
        'https://localhost/project/Test-Project/foo/bar/baz' =>
          "https://localhost/project/1/Test-Project/foo/bar/baz",
        301    # permanent
    );

    ok $t->get($_), "GET $_" for 'https://localhost/project/doesnt-exist/foo';
    $t->status_is(404);
};

subtest "redirect to fix URLs" => sub {
    $t->redirect_is(
        "https://localhost/project/1" => "https://localhost/project/1/Test-Project",
        301    # permanent
    );

    my $secret_project_id = 2;
    my $secret_project    = $t->schema->resultset('Project')->find($secret_project_id);

    # this endpoint doesn't check any permissions but $c->go()s to another action
    # this might be dangerous if check don't happen there
    $t->redirect_is(
        "https://localhost/project/$secret_project_id" => "https://localhost/login?redirect=%2Fproject%2F2",
        302,    # temporary
        "/project/2 shortcut doesn't allow access to private projects, doesn't reveal their name"
    );
    $t->content_lacks( $secret_project->name );
    $t->content_lacks( $secret_project->url_name );

    $t->redirect_is(
        "https://localhost/project/1/tEST-pROJECT/recipes" =>
          "https://localhost/project/1/Test-Project/recipes",
        301     # permanent
    );

    $t->redirect_is(
        "https://localhost/project/$secret_project_id/I-cant-know-this-projects-name/recipes" =>
          'https://localhost/login?redirect='
          . "%2Fproject%2F$secret_project_id%2FI-cant-know-this-projects-name%2Frecipes",
        302,    # temporary
        "/project/2/foobar doesn't reveal the real name of project 2",
    );
    $t->content_lacks( $secret_project->name );
    $t->content_lacks( $secret_project->url_name );

    $t->redirect_is(
        "https://localhost/project/1/completely-different-string/recipes" =>
          "https://localhost/project/1/Test-Project/recipes",
        301     # permanent
    );

    # with path arguments
    $t->redirect_is(
        "https://localhost/project/1/tEST-pROJECT/recipe/1" =>
          "https://localhost/project/1/Test-Project/recipe/1",
        301     # permanent
    );

    $t->redirect_is(
        "https://localhost/project/1/completely-different-string/recipe/1" =>
          "https://localhost/project/1/Test-Project/recipe/1",
        301     # permanent
    );

    # with query string
    $t->redirect_is(
        "https://localhost/project/1/tEST-pROJECT/recipes?keyword" =>
          "https://localhost/project/1/Test-Project/recipes?keyword",
        301     # permanent
    );

    $t->redirect_is(
        "https://localhost/project/1/tEST-pROJECT/recipes?key=val" =>
          "https://localhost/project/1/Test-Project/recipes?key=val",
        301     # permanent
    );

    subtest "response is equal for existent/inexistent objects in private project" => sub {
        my $existent_url   = "https://localhost/project/3/Other-Project/recipe/3";
        my $inexistent_url = "https://localhost/project/3/Other-Project/recipe/999";

        ok $t->get($_), "GET $_" for $inexistent_url;
        my $status  = $t->status;
        my $content = $t->content;
        $content =~ s/999/3/g;    # ID given in URL may be included

        ok $t->get($_), "GET $_" for $existent_url;
        $t->status_is( $status, "Response code is the same" );
        $t->content_is( $content, "Content is the same" );

        $t->get_ok('/');
        $t->login_ok( other => 'P@ssw0rd' );

        $t->get($existent_url);
        $t->status == 200 or die "test broken";

        $t->get($inexistent_url);
        $t->status == 404 or die "test broken";
    };

    ok $t->get($_), "GET $_" for "https://localhost/project/2/I-cant-know-this-projects-name/";
    $t->status_is( 403, "no redirect that would reveal the private project's name" );
    $t->lacks_header_ok('Location');
    $t->content_lacks( $secret_project->name );
    $t->content_lacks( $secret_project->url_name );

    $t->logout_ok();
};

subtest import => sub {
    $t->get_ok('/');
    $t->login_ok( john_doe => 'P@ssw0rd' );

    my $project = $t->schema->resultset('Project')->create(
        {
            name        => 'empty project',
            description => "",
            owner_id    => 1,
        }
    );
    my $base_url = "/project/" . $project->id . "/" . $project->url_name;

    $t->get_ok("$base_url/import");
    $t->content_lacks(
        'data-bs-title="Nothing can be imported because there already is data in all categories"');

    $t->get_ok('/project/1/Test-Project/import');
    $t->content_contains(
        'data-bs-title="Nothing can be imported because there already is data in all categories"');

    # former bug: properties are stored in a package variable and were
    # modified through a reference given by Model::ProjectImporter
    $t->get_ok("$base_url/import");
    $t->content_lacks(
        'data-bs-title="Nothing can be imported because there already is data in all categories"');

    $t->logout_ok();
};

my $project = $t->schema->resultset('Project')->create(
    {
        name        => 'Statistics Project',
        description => "",
        owner_id    => 1,
        archived    => '2000-01-01 00:00:00',
    }
);

my $base_url = "/project/" . $project->id . "/" . $project->url_name;

message_contains('archived');
$t->content_lacks('unarchive this project');

$t->login_ok( john_doe => 'P@ssw0rd' );
message_contains('archived');
$t->content_contains('unarchive this project');
$t->logout_ok();

$project->update( { archived => undef } );

message_lacks( 'message-info', "no message at all if not logged in" );

$t->login_ok( john_doe => 'P@ssw0rd' );
message_contains('fresh project');

{
    my $meal =
      $project->create_related( meals => { date => '1970-01-01', name => 'breakfast', comment => '' } );

    message_like(qr/ lacks .+ units /x);
    $meal->delete();
}

$project->create_related( tags => { name => 'foo' } );
message_like(qr/ lacks .+ units /x);

my $unit = $project->create_related( units => { short_name => 'kg', long_name => 'kilograms' } );
message_like(qr/ lacks .+ articles /x);

my $article = $project->create_related(
    articles => {
        name    => 'apples',
        comment => '',
    }
);
$article->add_to_units($unit);
message_like(qr/ lacks .+ meals .+ recipes? /msx);

$project->create_related(
    recipes => { name => 'apple pie', servings => 42, preparation => '', description => '' } );
message_like(qr/ lacks .+ meals (?! .+ recipes ) /x);

my $meal =
  $project->create_related( meals => { date => '2000-01-01', name => "lunch", comment => "" } );
message_like(qr/ lacks .+ dishes (?! .+ ( meals | recipes ) ) /x);

my $dish = $meal->create_related( dishes =>
      { name => 'apple pie', servings => 42, preparation => "", description => "", comment => "" } );
my $ingredient = $dish->create_related( ingredients =>
      { prepare => 0, value => 42, unit_id => $unit->id, article_id => $article->id, comment => "" } );
message_like(qr/ lacks .+ purchase\ lists /x);

my $list =
  $project->create_related( purchase_lists => { date => '2000-01-01', name => "purchase list" } );
message_contains('stale');

$list->update( { date => $list->format_date( DateTime->today->add( years => 1 ) ) } );
message_contains('print');

$t->content_lacks( my $html =
      q(data-bs-title="Nothing can be imported because there already is data in all categories") );

$project->create_related( shop_sections => { name => "Meat" } );
$t->reload_ok();
$t->content_contains($html);

sub message_contains {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $t->get_ok($base_url);
    $t->text_contains(@_)
      or note $t->text;
}

sub message_lacks {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $t->get_ok($base_url);
    $t->text_lacks(@_)
      or note $t->text;
}

sub message_like {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $t->get_ok($base_url);
    $t->text_like(@_)
      or note $t->text;
}

subtest "project deletion" => sub {
    $t->get_ok('/project/1/Test-Project/settings');

    $t->submit_form_ok( { form_name => 'delete', with_fields => { confirmation => 'foo' } } );
    $t->text_contains("not deleted");

    $t->submit_form_ok( { form_name => 'delete', with_fields => { confirmation => 'Test Project' } } );
    $t->base_is('https://localhost/');
    $t->text_contains('Test Project');
    $t->text_contains('deleted');

    $t->reload_ok();
    $t->text_lacks('Test Project')
      or note $t->content;
};
