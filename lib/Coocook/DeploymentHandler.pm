package Coocook::DeploymentHandler;

use strict;
use warnings;

use parent 'DBIx::Class::DeploymentHandler';

use File::Spec;

sub new {
    my ( $self, $args ) = @_;

    my $script_directory = $args->{script_directory};

    $script_directory eq 'share/ddl'
      or warn "Unexpected script_directory: $script_directory";

    # Since Perl 5.26 @INC doesn't contain '.' anymore and
    # includes of .pl files do require qualified paths.
    # I tried './share/ddl' but DBIx::Class::DeploymentHandler finds files
    # and removes the './' part. Absolute path works.
    local $args->{script_directory} = File::Spec->rel2abs($script_directory);

    $self->next::method($args);
}

{    # workaround to let Producer::SQLite NOT mangle index names
    use SQL::Translator::Producer::SQLite;
    no warnings 'redefine';
    my $orig = \&SQL::Translator::Producer::SQLite::mk_name;
    *SQL::Translator::Producer::SQLite::mk_name = sub {
        my ($name) = @_;
        my $ret = $orig->(@_);
        $ret eq $name or $ret eq qq("$name") or warn "mk_name(@_) => $ret";
        return $name;
    };
}

1;
