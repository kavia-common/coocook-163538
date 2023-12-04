use Test2::V0;

use Coocook::Util;

my $name          = '!Geheimes - Projekt!';
my $original_name = "$name";

is Coocook::Util::url_name($name) => '-Geheimes-Projekt-',
  "url_name()";

is Coocook::Util::url_names_hashref($name) => {
    url_name    => '-Geheimes-Projekt-',
    url_name_fc => '-geheimes-projekt-',
  },
  "url_names_hash_list()";

is $name => $original_name, "original value untouched";

subtest username_valid => sub {
    like dies { Coocook::Util::username_valid() } => qr/Too few arguments for subroutine/,
      "croaks for no argument";

    ok Coocook::Util::username_valid("foo"),    "valid username";
    ok !Coocook::Util::username_valid("foo!"),  "invalid char";
    ok !Coocook::Util::username_valid(""),      "empty string";
    ok !Coocook::Util::username_valid("foo\n"), "trailing newline (typical pitfall with Perl regexp)";
};

done_testing();
