package Test::Coocook;

use strict;
use warnings;
use experimental qw(signatures);

use Test2::V0 ();    # with () this does NOT enable strict + warnings

use Carp;
use Email::Sender::Simple;
use HTML::Meta::Robots;
use JSON::MaybeXS;
use Regexp::Common 'URI';
use Scope::Guard qw< guard >;
use TestDB;
use WWW::Mechanize::TreeBuilder;

BEGIN {
    # don't actually send any emails
    $ENV{EMAIL_SENDER_TRANSPORT} = 'Test';

    # point Catalyst to t/ to avoid reading local config files
    $ENV{COOCOOK_CONFIG} = 't/';
}

our $DEBUG //= $ENV{TEST_COOCOOK_DEBUG};

# don't spill STDERR with info messages when not in verbose mode
our $DISABLE_LOG_LEVEL_INFO //= !$ENV{TEST_VERBOSE};

use parent 'Test::WWW::Mechanize::Catalyst';

=head1 CONSTRUCTOR

=cut

sub new ( $class, %args ) {
    defined( $args{deploy} ) && $args{schema}
      and croak "Can't use both arguments 'deploy' and 'schema'";

    my $config = delete $args{config};
    my $schema = delete $args{schema};

    my $deploy    = delete $args{deploy}    // 1;
    my $test_data = delete $args{test_data} // 1;

    my $self = $class->next::method(
        catalyst_app => 'Coocook',
        strict_forms => 1,           # change default to true
        %args
    );

    if ($DISABLE_LOG_LEVEL_INFO) {
        $self->catalyst_app->log->disable('info');
    }

    $schema //= TestDB->new( deploy => $deploy, test_data => $test_data );

    $self->catalyst_app->model('DB')->schema->storage( $schema->storage );

    $config
      and $self->reload_config($config);

    # for `findnodes` method, which can find HTML elements with XPath
    WWW::Mechanize::TreeBuilder->meta->apply( $self, tree_class => 'HTML::TreeBuilder::XPath' );

    return $self;
}

=head1 METHODS

=cut

sub request {
    my $self = shift;
    my ($request) = @_;

    my $response = $self->next::method(@_);

    if ($DEBUG) {
        for ( [ '> ', $request ], [ '< ', $response ] ) {
            my ( $prefix, $message ) = @$_;

            Test2::V0::note map { my $s = $_; $s =~ s/^/$prefix/gm; $s } $message->headers->as_string, "\n",
              ( $message->content_length > 0 ? $message->decoded_content : () );
        }
    }

    return $response;
}

sub emails {
    return [ Email::Sender::Simple->default_transport->deliveries ];
}

sub clear_emails ($self) {
    $self->{coocook_checked_email_count} = 0;
    Email::Sender::Simple->default_transport->clear_deliveries;
}

sub shift_emails ( $self, $n = 1 ) {
    defined and $_ -= $n for $self->{coocook_checked_email_count};
    Email::Sender::Simple->default_transport->shift_deliveries for 1 .. $n;
}

sub email_count_is ( $self, $count, $name = undef ) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $self->{coocook_checked_email_count} = $count;

    Test2::V0::is(
        Email::Sender::Simple->default_transport->deliveries => $count,
        $name || sprintf( "%i emails stored", $count )
    );
}

sub local_config_guard {
    my $self = shift;

    my $original_config = $self->catalyst_app->config;

    @_ and $self->reload_config(@_);

    return guard { $self->reload_config($original_config) };
}

=head2 $t->reload_config(\%config)

=head2 Test::Coocook->reload_config(\%config)

When called as a class method acts globally on L<Coocook>.

=cut

sub reload_config {
    my $self = shift;

    my $app = ref $self ? $self->catalyst_app : 'Coocook';

    $app->setup_finished(0);

    # Plugin::Static::Simple warns if $c->config->{static} exists
    # but creates this hash key itself in before(setup_finalize => sub {...})
    delete $app->config->{static};

    $app->config(@_);
    $app->setup_finalize();
}

sub schema { shift->catalyst_app->model('DB')->schema(@_) }

=head1 TEST METHODS

=cut

sub register_ok ( $self, $field_values, $name = "register" ) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    Test2::V0::subtest $name, sub {
        $self->follow_link_ok( { text => 'Sign up' } );

        $self->submit_form_ok( { with_fields => $field_values },
            "register account '$field_values->{username}'" );

        $self->text_like(qr/email/)
          or Test2::V0::note $self->text;
    };
}

sub register_fails_like ( $self, $field_values, $error_regex,
    $name = "register fails like '$error_regex'" )
{
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    Test2::V0::subtest $name => sub {
        $self->follow_link_ok( { text => 'Sign up' } );

        $self->submit_form_fails( { with_fields => $field_values },
            "register account '$$field_values{username}' ..." );

        $self->text_like($error_regex)
          or Test2::V0::note $self->text;
    };
}

=head2 get_ok_email_link_like( qr/.../, "test name"? )

=head2 get_ok_email_link_like( qr/.../, $expected_status, "test name" )

Matches all URLs found in the email against the given regex
and calls C<get_ok()> on that URL.

=cut

sub get_ok_email_link_like {
    my $self            = shift;
    my $regex           = shift;
    my $name            = pop || "GET link from first email";
    my $expected_status = pop;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    Test2::V0::subtest $name, sub {
        my $body = $self->_get_email_body();

        my @urls;

        while ( $body =~ m/$RE{URI}{HTTP}{ -scheme => 'https' }{-keep}/g ) {
            my $url = $1;    # can't match in list context because RE has groups

            $url =~ $regex
              and push @urls, $url;
        }

        if ( not Test2::V0::is( scalar @urls => 1, "found 1 URL matching $regex" ) ) {
            Test2::V0::note $body;
            return;
        }

        if ($expected_status) {
            $self->get( $urls[0] );
            $self->status_is($expected_status);
        }
        else {
            $self->get_ok( $urls[0] );
        }
    };
}

sub email_like   { shift->_email_un_like( 1, @_ ) }
sub email_unlike { shift->_email_un_like( 0, @_ ) }

sub _email_un_like ( $self, $like, $regex, $name = "first email like $regex" ) {
    local $Test::Builder::Level = $Test::Builder::Level + 2;

    my $body = $self->_get_email_body;

    if ( not defined $body ) {
        Test2::V0::fail $name;
        return;
    }

    if ($like) {
        my @matches = ( $body =~ m/$regex/g );

        Test2::V0::ok @matches >= 1, $name
          or Test2::V0::note $body;

        return @matches;
    }
    else {
        my $ok = Test2::V0::unlike( $body => $regex, $name )
          or Test2::V0::note $body;

        return $ok;
    }
}

sub _get_email_body ($self) {
    my $emails = $self->emails;

    {
        local $Carp::Internal{'Test2::API'}            = 1;
        local $Carp::Internal{'Test2::Tools::Subtest'} = 1;
        local $Carp::Internal{'Test::Coocook'}         = 1;

        if ( @$emails == 0 ) {
            carp "no emails stored";
            return;
        }

        my $checked = $self->{coocook_checked_email_count} || 1;

        @$emails > $checked
          and carp "More than 1 email stored";
    }

    my $email = $emails->[0]->{email};    # use first email

    return $email->get_body;
}

sub is_logged_in ( $self, $name = "client is logged in" ) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $self->text_contains( 'Settings', $name )
      or Test2::V0::note $self->text;
}

sub is_logged_out ( $self, $name = "client is logged out" ) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $self->text_like( qr/Sign [Ii]n/, $name )
      or Test2::V0::note $self->text;
}

sub login ( $self, $username, $password, %additional_fields ) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $self->follow_link_ok( { text => 'Sign in' } );

    $self->submit_form_ok(
        {
            with_fields => {
                username => $username,
                password => $password,
                %additional_fields
            },
        },
        "submit login form"
    );
}

=head2 $t->login_ok($username, $password, %additional_fields?, $name?)

=cut

sub login_ok {
    my $name = @_ % 2 ? undef : pop(@_);
    my ( $self, $username, $password, %additional_fields ) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    Test2::V0::subtest $name || "login with $username:$password", sub {
        my $orig_max_redirect = $self->max_redirect;
        $self->max_redirect(3);

        $self->login( $username, $password, %additional_fields );

        $self->is_logged_in();

        $self->max_redirect($orig_max_redirect);
    };
}

sub login_fails ( $self, $username, $password, $name = "login with $username:$password fails" ) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    Test2::V0::subtest $name, sub {
        $self->login( $username, $password );

        ( $self->text_like(qr/fail/) and $self->text_like(qr/Sign in/) )
          or Test2::V0::note $self->text;
    };
}

sub logout_ok ( $self, $name = "click logout button" ) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $self->click_ok( 'logout', $name );
}

sub change_display_name_ok ( $self, $display_name, $name = "change display name" ) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    Test2::V0::subtest $name, sub {
        $self->follow_link_ok( { text => 'Settings' } );

        $self->submit_form_ok(
            {
                with_fields => {
                    display_name => $display_name,
                },
            },
            "submit change display name form"
        );
    };
}

sub request_recovery_link_ok ( $self, $email, $name = "request recovery link for $email" ) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    Test2::V0::subtest $name, sub {
        my $logged_in = ( $self->text =~ m/Settings/ );

        if ($logged_in) {
            $self->follow_link_ok( { text => 'Settings' } );
            $self->follow_link_ok( { text => 'request a recovery link' } );
        }
        else {
            $self->follow_link_ok( { text => 'Sign in' } );
            $self->follow_link_ok( { text => 'Lost your password?' } );
        }

        $self->submit_form_ok(
            {
                with_fields => {
                    email => $email,
                },
            },
            "submit email recovery form"
        );

        $self->text_contains('Recovery link sent')
          or Test2::V0::note $self->text;
    };
}

sub create_project_ok ( $self, $fields, $name = "create project '$fields->{name}'" ) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    Test2::V0::subtest $name, sub {
        $self->get_ok('/');

        $self->submit_form_ok( { with_fields => $fields }, "submit create project form" );

        $self->text_contains( $fields->{name} )
          or Test2::V0::note $self->text;
    };
}

sub checkbox_is_on  { shift->_checkbox_is_on_off( 1, @_ ) }
sub checkbox_is_off { shift->_checkbox_is_on_off( 0, @_ ) }

sub _checkbox_is_on_off ( $self, $expected, $input, $name = undef ) {
    local $Test::Builder::Level = $Test::Builder::Level + 2;

    my $value = $self->value($input);

    if ($expected) {
        Test2::V0::is $value => 'on', $name || "checkbox '$input' is checked";
    }
    else {
        Test2::V0::is $value => undef, $name || "checkbox '$input' is not checked";
    }
}

=head2 input_has_value($input, $value, $test_name?)

Finds input element with name C<$input> globally on the page (name must be unique)
and compares value to the expected C<$value>.

=cut

sub input_has_value ( $self, $input, $value, $name = "Input with name '$input' has value '$value'" )
{
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my @inputs = $self->find_all_inputs( name => $input );

    @inputs == 1
      or croak "More than 1 input element";

    Test2::V0::is( $inputs[0]->value => $value, $name )
      or Test2::V0::note $self->content;
}

sub json_is ( $self, $expected, $name = "JSON in response content" ) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $json = decode_json $self->content;
    Test2::V0::is $json => $expected, $name;
}

sub redirect_is ( $self, $url, $expected, $status, $name = "GET $url redirects $status $expected" )
{
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    Test2::V0::subtest $name => sub {
        my $original_max_redirect = $self->max_redirect();
        $self->max_redirect(0);

        Test2::V0::ok $self->get($url), "GET $url";
        $self->status_is($status);
        $self->header_is( Location => $expected );

        $self->max_redirect($original_max_redirect);
    };
}

sub reload_ok ($self) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    Test2::V0::ok $self->reload(), $self->base ? "reload " . $self->base : "reload";
}

sub robots_flags_ok ( $self, $flags,
    $name = "Response contains 'robots' meta tag with specified flags" )
{
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $fail = sub {
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        Test2::V0::fail $name;
        Test2::V0::diag $_ for @_;
    };

    my @matches = ( $self->content =~ m/ <meta \s+ name="robots" \s+ content="([^"<>]*)"> /gx );

    if    ( @matches == 0 ) { return $fail->("Can't find 'robots' meta tag") }
    elsif ( @matches > 1 )  { return $fail->("Found more than 1 'robots' meta tag") }

    my $string = $matches[0];
    my $robots = HTML::Meta::Robots->new->parse($string);

    for ( sort keys %$flags ) {
        my ( $flag => $expected ) = $flags->%{$_};

        if ( $robots->$flag xor $expected ) {
            return $fail->(
                "Wrong value for flag '$flag'",
                "Found:    '$string'",
                "Expected: " . ( $expected ? "'$flag'" : "'no$flag'" )
            );
        }
    }

    Test2::V0::pass $name;
}

sub status_is ( $self, $expected, $name = undef ) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $ok = Test2::V0::is $self->response->code => $expected,
      $name || sprintf(
        "Response code %i for %s %s",
        $expected,
        $self->response->request->method,
        $self->response->request->uri
      );

    if ( not $ok and $self->response->code =~ m/301|302|303|307|308/ ) {
        Test2::V0::diag "Location: " . $self->response->header('Location');
    }

    return $ok;
}

sub status_like ( $self, $expected, $name = "Response has status code like '$expected'" ) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    Test2::V0::like $self->response->code => $expected, $name;
}

sub submit_form_fails ( $self, $params, $name = undef ) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $res = $self->submit_form(%$params);

    if ( not $res ) {
        Test2::V0::fail $name;
        return;
    }

    $self->status_is( 400, $name )
      or return;

    return $res;
}

1;
