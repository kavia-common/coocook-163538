use Test2::V0;
use Test2::Require::AuthorTesting;

use Sub::Override;
use Test::PerlTidy;

note "Perl::Tidy version " . $Perl::Tidy::VERSION;

our $WANTED_PERLTIDY_VERSION = '20230912';    # XXX when upgrading change "cpanfile" accordingly!

$Perl::Tidy::VERSION eq $WANTED_PERLTIDY_VERSION
  or warn "Perl::Tidy version isn't $WANTED_PERLTIDY_VERSION!";

# workaround for including additional files to test
# TODO might become obsolete by https://github.com/shlomif/Test-PerlTidy/pull/10
my $orig     = \&Test::PerlTidy::list_files;
my $override = Sub::Override->new(
    'Test::PerlTidy::list_files',
    sub {
        return (
            $orig->(@_),    # default
            'cpanfile',
            'coocook.psgi',
        );
    }
);

run_tests(
    exclude => [
        qr{ ^\.build/ }x,                 # Dist::Zilla build directory
        qr{ ^blib/ }x,                    # build directory
        qr{ ^Coocook- \d+ \. \d+ / }x,    # Dist::Zilla output directories
        qr{ ^perl5/ }x,                   # installed CPAN modules in GitLab CI
    ]
);
