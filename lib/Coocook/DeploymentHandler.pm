package Coocook::DeploymentHandler;

use strict;
use warnings;

use parent 'DBIx::Class::DeploymentHandler';

use File::Spec;
use Sub::Util qw(set_subname);

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

sub upgrade {
    my $self = shift;

    $self->schema->storage->sqlt_type eq 'SQLite'
      or return $self->next::method(@_);

    # next::method() doesn't work without subname() inside a coderef
    my $orig = set_subname __PACKAGE__ . '::upgrade' => sub { $self->next::method(@_) };

    # DBIC::DeploymentHandler wraps our upgrade SQLs in txn_do().
    # In SQLite disabling the pragma 'foreign_keys' inside this transaction
    # has no effect and removing tables with the pragma in effect doesn't work.
    # So we disable the pragma for all upgrade scripts.
    return $self->schema->fk_checks_off_do( $orig, @_ );
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
