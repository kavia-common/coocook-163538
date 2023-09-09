use Test2::V0;
use Test2::Require::AuthorTesting;
use Test::PerlTidy;

note "Perl::Tidy version " . $Perl::Tidy::VERSION;

run_tests(
    exclude => [
        qr{ ^\.build/ }x,                 # Dist::Zilla build directory
        qr{ ^blib/ }x,                    # build directory
        qr{ ^Coocook- \d+ \. \d+ / }x,    # Dist::Zilla output directories
        qr{ ^perl5/ }x,                   # installed CPAN modules in GitLab CI
    ]
);
