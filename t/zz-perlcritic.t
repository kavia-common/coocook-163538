use Test2::V0;
use Test2::Require::AuthorTesting;
use Test::Perl::Critic;
all_critic_ok( 'lib/', 'script/', 't/' );
