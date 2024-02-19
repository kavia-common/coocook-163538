use Coocook::Base;
use Test2::V0 -no_warnings => 1;

use lib 't/lib';
use Test::Coocook;

plan(13);

my $t = Test::Coocook->new(
    config       => { enable_user_registration => 1 },
    max_redirect => 0
);

subtest "attributes of controller actions" => sub {
    my $app = $t->catalyst_app;

    for ( sort $app->controllers ) {    # sort() required for stable order of tests
        my $controller = $app->controller($_);

        is [ $controller->meta->superclasses ] => ['Coocook::Controller'],
          "$controller directly inherits from Coocook::Controller";

        # - get_action_methods() returns a list of weird Moose::Meta::Method objects
        # - action_for($name) then returns the actual Catalyst::Action object
        #
        # see https://metacpan.org/pod/Catalyst::Controller#$self-%3Eget_action_methods()
      SKIP: for my $action_meta_object ( $controller->get_action_methods ) {
            my $action = $controller->action_for( $action_meta_object->name );

            # ignore internal methods from Catalyst
            grep { $action->name eq $_ } qw( _DISPATCH _BEGIN _AUTO _ACTION _END )
              and next;

            my $action_pkg_name = $action->class . "::" . $action->name . "()";
            $action_pkg_name =~ s/^Coocook:://;    # shorten pkg name in output

            # for some reason assigning attribute 'Private' to end() methods breaks the app
            $action->name eq 'end' and skip "$action_pkg_name is 'end' action";

            my %attrs = do {
                my @attrs = $action_meta_object->attributes->@*;
                s/ \( .+ $ //x for @attrs;    # remove arguments in parenthesis, e.g. RequiresCapability(foo)
                map { $_ => 1 } @attrs;
            };

            state %http_method_attrs = map { $_ => 1 } qw( AnyMethod DELETE GET HEAD POST PUT );
            my @used_http_methods = sort grep { $http_method_attrs{$_} } keys %attrs;

            if ( $attrs{Private} ) {
                pass "$action_pkg_name has 'Private'";
                next;
            }

            if ( $attrs{CaptureArgs} ) { # actions with CaptureArgs are chain elements and automatically private
                is \@used_http_methods => [], "$action_pkg_name with 'CaptureArgs' has no HTTP methods";
                next;
            }

            is \@used_http_methods => in_set( ['AnyMethod'], [ 'GET', 'HEAD' ], ['POST'] ),
              "$action_pkg_name has 'AnyMethod' or 'GET' & 'HEAD' or 'POST'";

            state @possible_authz_attrs = (
                'RequiresCapability',    # = see ActionRole::RequiresCapability
                'Public',                # = no permission required
                'CustomAuthz',           # = action is not public but does authorization in code
                                         #   TODO this could be tested:
                                         #   store flag, make require_capability() remove flag,
                                         #   run action, check that flag has been removed
            );

            ok $action->meta->does_role('Coocook::ActionRole::RequiresCapability'),
              "$action_pkg_name does ActionRole::RequiresCapability";

            my @used_authz_attrs = grep { $attrs{$_} } @possible_authz_attrs;

            is \@used_authz_attrs => [ in_set @possible_authz_attrs ],
              "$action_pkg_name has exactly 1 authorization attribute";
        }
    }
};

subtest "GET http://... redirects to HTTPS" => sub {
    $t->catalyst_app->debug and skip_all "Catalyst debug mode is active";

    $t->redirect_is(
        'http://localhost/' => 'https://localhost/',
        301    # moved permanently
    );

    $t->redirect_is(
        'http://localhost/path_doesnt_exist' => 'https://localhost/path_doesnt_exist',
        301    # moved permanently
    );
};

subtest "POST http://... is catched as well" => sub {    # TODO define exact behavior
    $t->post('http://localhost/');
    $t->status_like(qr/ ^[34] /x);
};

$t->get_ok('https://localhost');

subtest "HTTP Strict Transport Security" => sub {
    $t->get('http://localhost');
    $t->lacks_header_ok( 'Strict-Transport-Security', "no header for plain HTTP" );

    $t->get_ok('https://localhost');
    $t->header_is(
        'Strict-Transport-Security' => 'max-age=' . 365 * 24 * 60 * 60,
        "default"
    );

    $t->reload_config(
        'Plugin::StrictTransportSecurity' => {
            max_age             => 63072000,
            include_sub_domains => 1,
            preload             => 1
        }
    );

    $t->get_ok('https://localhost');
    $t->header_is(
        'Strict-Transport-Security' => 'max-age=63072000; includeSubDomains; preload',
        "with configuration"
    );
};

subtest "static URIs" => sub {
    delete local $ENV{COOCOOK_STATIC_BASE_URI};
    $t->reload_config(
        css => [
            '/lib/foo.css',    # relative to static/ of current request URI
            'https://example/bar.css',
        ]
    );

    subtest "no static base URI set" => sub {
        $t->get('/');
        $t->content_contains('https://localhost/static/css/style.css');
        $t->content_contains('https://localhost/static/lib/foo.css');
        $t->content_contains('https://example/bar.css');

        is $t->catalyst_app->uri_for_static( '/foo', 42, { key => 'value' }, \'fragment' ) =>
          '/static/foo/42?key=value#fragment',
          "complex uri_for() args";
    };

    local $ENV{COOCOOK_STATIC_BASE_URI} = 'http://from-env';

    subtest "static base URI from env var" => sub {
        $t->reload_config();
        $t->get('/');
        $t->content_contains('http://from-env/css/style.css');
        $t->content_contains('https://localhost/static/lib/foo.css');
        $t->content_contains('https://example/bar.css');
    };

    subtest "static base URI from env var overrides config" => sub {
        $t->reload_config( static_base_uri => 'http://from-config' );
        $t->get('/');
        $t->content_contains('http://from-env/css/style.css');
        $t->content_contains('https://localhost/static/lib/foo.css');
        $t->content_contains('https://example/bar.css');
    };

    local $ENV{COOCOOK_STATIC_BASE_URI} = '';

    subtest "empty env var can disable value from config" => sub {
        $t->reload_config( static_base_uri => 'http://from-config' );
        $t->get('/');
        $t->content_contains('https://localhost/static/css/style.css');
        $t->content_contains('https://localhost/static/lib/foo.css');
        $t->content_contains('https://example/bar.css');
    };

    delete local $ENV{COOCOOK_STATIC_BASE_URI};

    subtest "static base URI from config" => sub {
        $t->reload_config( static_base_uri => 'http://from-config' );
        $t->get('/');
        $t->content_contains('http://from-config/css/style.css');
        $t->content_contains('https://localhost/static/lib/foo.css');
        $t->content_contains('https://example/bar.css');

        $t->reload_config( static_base_uri => 'scheme://user@host:1234/path/' );
        $t->get('/');
        $t->content_contains( 'scheme://user@host:1234/path/css/style.css', "complex value" );
    };
};

subtest content_security_policy => sub {
    $t->get('/');
    $t->header_is(
        'Content-Security-Policy' => q(connect-src 'self'; img-src data: 'self'; font-src 'self';) );

    $t->get('/foobar');
    $t->status_is(404);
    $t->header_exists_ok( 'Content-Security-Policy', "CSP for error pages" );

    $t->get_ok('/static/js/script.js');
    $t->lacks_header_ok( 'Content-Security-Policy', "no CSP for static files" );

    $t->get_ok('/project/1/Test-Project/project_plan');
    $t->lacks_header_ok( 'Content-Security-Policy', "no CSP for Ajax responses" );

    my $guard = $t->local_config_guard;    # undo changes at end of block

    $t->reload_config(
        static_base_uri         => 'https://coocook-cdn.example/',
        content_security_policy => undef,                            # reset
    );
    $t->get('/');
    $t->header_is( 'Content-Security-Policy' =>
q(connect-src 'self'; img-src data: https://coocook-cdn.example/; font-src https://coocook-cdn.example/;)
    );

    $t->reload_config( content_security_policy => '' );    # defined but false
    $t->get('/');
    $t->lacks_header_ok('Content-Security-Policy');

    my $csp = 'csp' . __FILE__ . __LINE__;
    $t->reload_config( content_security_policy => $csp );
    $t->get('/');
    $t->header_is( 'Content-Security-Policy' => $csp );
};

subtest "robots meta tag" => sub {
    $t->get_ok('/');
    $t->robots_flags_ok( { archive => 1, index => 1 } );

    subtest "404 pages" => sub {
        $t->get('/doesnt_exist');
        $t->status_is(404);
        $t->robots_flags_ok( { archive => 0, index => 0 } );
    };

    subtest "bad request pages" => sub {
        my $guard = $t->local_config_guard( enable_user_registration => 1 );

        $t->get_ok('/register');
        $t->submit_form_fails( { with_fields => { username => '' } }, "submit form" );
        $t->robots_flags_ok( { archive => 0, index => 0 } );
    };

    subtest "internal server error" => sub {
        ok $t->get('/internal_server_error'), "GET /internal_server_error";
        $t->status_is(404);

        no warnings 'once';
        $Coocook::Controller::Error::ENABLE_INTERNAL_SERVER_ERROR_PAGE = 1;

        $t->get_ok('/internal_server_error');
        $t->status_is(200);
        $t->robots_flags_ok( { archive => 0, index => 0 } );
    };

    subtest "under simulation of fatal mistake in permission" => sub {
        $t->get('/project/3/Other-Project');
        $t->status_is(302);    # actually the login page

        note "manipulating Model::Authorization ...";
        no warnings qw< once redefine >;
        ok local *Coocook::Model::Authorization::has_capability = sub { 1 },    # everything allowed
          "install simulation";

        $t->reload_ok();
        $t->status_is(200);                                                     # not the login page

        $t->robots_flags_ok( { archive => 0, index => 0 } );
    };

    $t->max_redirect(1);

    $t->login_ok( 'john_doe', 'P@ssw0rd' );
    $t->get_ok('/');
    $t->robots_flags_ok( { archive => 0, index => 0 } );
};

subtest "Redirect URL parameter" => sub {
    $t->logout_ok();

    # no 'redirect' parameter for these paths
    for my $path ( '/', '/login', '/register' ) {
        $t->get_ok($path);
        $t->content_contains(q{href="https://localhost/login"});
        $t->content_contains(q{href="https://localhost/register"});
    }

    # default
    $t->get_ok('/statistics');
    $t->content_contains(q{/login?redirect=%2Fstatistics"});

    # query parameter
    $t->get_ok('/?key=value');
    $t->content_contains(q{/login?redirect=%2F%3Fkey%3Dvalue"});

    # redirect path is passed around between login/redirect
    $t->get_ok('/statistics?key=value');
    $t->follow_link_ok( { text => 'Sign up' } );
    $t->max_redirect(1);
    $t->login_ok( 'john_doe', 'P@ssw0rd' );
    $t->base_is('https://localhost/statistics?key=value');
};

subtest favicons => sub {
    $t->get_ok('/');
    $t->content_lacks('<link.+icon');

    $t->reload_config(
        icon_type => 'image/x-icon',
        icon_url  => '/alpha.ico',
        icon_urls => {
            ''      => '/beta.png',
            '72x72' => 'https://example/72.png',    # absolute URL
        },
    );
    $t->reload_ok();
    $t->content_contains(q{<link rel="icon" type="image/x-icon" href="https://localhost/alpha.ico">});
    $t->content_contains(q{<link rel="apple-touch-icon"  href="https://localhost/beta.png">});
    $t->content_contains(q{<link rel="apple-touch-icon" sizes="72x72" href="https://example/72.png">});

    my $guard = $t->local_config_guard( icon_url => 'no scheme or root slash' );

    # Test2::Tools::Exception doesn't catch server side errors here.
    # workaround stolen from
    # https://github.com/perl-catalyst/catalyst-runtime/blob/master/t/data_handler.t
    my $stderr;
    {
        local *STDERR;
        open( STDERR, ">", \$stderr ) or die "Can't open STDERR: $!";
        $t->get('/');
    }
    like
      $stderr => qr/absolute URI/,
      "error string that is not absolute URI or absolute path";
    $t->status_is(500);
};

subtest "canonical URLs" => sub {
    $t->get_ok('/');
    $t->content_lacks('canonical');

    my $url_base = 'https://www.coocook.example/coocook/';

    my $guard = $t->local_config_guard( canonical_url_base => $url_base );

    $t->get_ok('/');
    $t->content_contains(qq{<link rel="canonical" href="$url_base">});

    $t->get_ok('/statistics?key=value#anchor');
    $t->content_contains(qq{<link rel="canonical" href="${url_base}statistics">});

    ok $t->get($_), "GET $_", for '/doesnt-exist';
    $t->content_lacks('canonical');
};

subtest "me URL" => sub {
    $t->get_ok('/');
    $t->content_lacks(q{rel="me"});
    my $guard = $t->local_config_guard( me_url => 'https://me.example/' );
    $t->get_ok('/');
    $t->content_contains(q{<link rel="me" href="https://me.example/">});
};

subtest "simply check GET for all endpoints" => sub {    # TODO could we autogenerate the URL list?
    $t->max_redirect(0);

    $t->get_ok('/');
    $t->get_ok('/about');
    $t->get_ok('/admin');
    $t->get_ok('/admin/faq');
    $t->get_ok('/admin/faq/1');
    $t->get_ok('/admin/faq/new');
    $t->get_ok('/admin/organizations');
    $t->get_ok('/admin/projects');
    $t->get_ok('/admin/terms');
    $t->get_ok('/admin/terms/2');
    $t->get_ok('/admin/terms/new');
    $t->get_ok('/admin/user/other');
    $t->get_ok('/admin/users');
    $t->get_ok('/badge/dishes_served.svg');
    $t->get_ok('/faq');
    $t->get_ok('/internal_server_error');
    $t->get_ok('/organization/TestData');
    $t->get_ok('/organization/TestData/members');
    $t->get_ok('/projects');
    $t->get_ok('/project/1/Test-Project');
    $t->get_ok('/project/1/Test-Project/article/1');
    $t->get_ok('/project/1/Test-Project/articles');
    $t->get_ok('/project/1/Test-Project/articles/new');
    $t->get_ok('/project/1/Test-Project/dish/1');
    $t->get_ok('/project/1/Test-Project/edit');
    $t->get_ok('/project/1/Test-Project/import');
    $t->get_ok('/project/1/Test-Project/items/unassigned');
    $t->get_ok('/project/1/Test-Project/permissions');
    $t->get_ok('/project/1/Test-Project/print/day/2000/1/1');
    $t->get_ok('/project/1/Test-Project/purchase_list/1');
    $t->get_ok('/project/1/Test-Project/purchase_lists');
    $t->get_ok('/project/1/Test-Project/recipe/1');
    $t->get_ok('/project/1/Test-Project/recipes');
    $t->get_ok('/project/1/Test-Project/recipes/import');
    $t->get_ok('/project/1/Test-Project/recipes/import/2');
    $t->get_ok('/project/1/Test-Project/settings');
    $t->get_ok('/project/1/Test-Project/shop_sections');
    $t->get_ok('/project/1/Test-Project/tag/1');
    $t->get_ok('/project/1/Test-Project/tags');
    $t->get_ok('/project/1/Test-Project/unit/1');
    $t->get_ok('/project/1/Test-Project/units');
    $t->get_ok('/recipe/1/pizza');
    $t->get_ok('/recipe/1/pizza/import');
    $t->get_ok('/recipes');
    $t->get_ok('/recover');
    $t->redirect_is( '/settings' => 'https://localhost/settings/account', 302 );
    $t->get_ok('/settings/account');
    $t->get_ok('/settings/organizations');
    $t->get_ok('/settings/projects');
    $t->get_ok('/statistics');
    $t->redirect_is( '/terms' => 'https://localhost/terms/1', 302 );
    $t->get_ok('/terms/1');
    $t->get_ok('/user/john_doe');
};
