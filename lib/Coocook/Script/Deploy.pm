package Coocook::Script::Deploy;

# ABSTRACT: script for database maintance based on App::DH

use Moose;
use namespace::autoclean;

use Coocook::DeploymentHandler;
use File::Spec;
use PerlX::Maybe;

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

extends 'App::DH';

has '+schema' => ( default => 'Coocook::Schema' );

# Since Perl 5.26 @INC doesn't contain '.' anymore and
# includes of .pl files do require qualified paths.
# I tried './share/ddl' but DBIx::Class::DeploymentHandler finds files
# and removes the './' part. Absolute path works.
has '+script_dir' => ( default => File::Spec->rel2abs('share/ddl') );

sub _build_database { [qw< SQLite PostgreSQL >] }

sub _build__dh {    # copy from App::DH
    my ($self) = @_;
    return Coocook::DeploymentHandler->new(    # adjusted to custom class
        {
            schema           => $self->_schema,
            force_overwrite  => $self->force,
            script_directory => $self->script_dir,
            databases        => $self->database,
            maybe to_version => $self->target,
        },
    );
}

__PACKAGE__->meta->make_immutable;

1;
