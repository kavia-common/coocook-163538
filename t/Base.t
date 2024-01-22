use Coocook::Base;
use Test2::V0;

{

    package PkgWithoutMoose;    ## no critic (RequireFilenameMatchesPackage)

    use Coocook::Base;
    use Carp;

    sub f { carp 'foo' }
}

{

    package PkgWithMoose;

    use Coocook::Base qw( Moose MooseX::NonMoose );
    use Carp;

    sub f { carp 'bar' }

    __PACKAGE__->meta->make_immutable;
}

subtest PkgWithoutMoose => sub {
    like warning { PkgWithoutMoose->f() } => qr/^foo/, "PkgWithoutMoose->f() does carp()";
    ok defined &PkgWithoutMoose::carp,  "used carp() from Carp hasn't been cleaned";
    ok defined &PkgWithoutMoose::croak, "unused croak() from Carp hasn't been cleaned";
    ok !defined &PkgWithoutMoose::meta, "package has no meta() from Moose";
};

subtest PkgWithMoose => sub {
    like warning { PkgWithMoose->f() } => qr/^bar/, "PkgWithMoose->f() does carp()";
    ok !defined &PkgWithMoose::croak, "unused croak() from Carp has been cleaned";
    ok defined &PkgWithMoose::meta,   "package has meta() from Moose";
};

like dies { Coocook::Base->import(qw( Carp DoesntExist )) } => qr/Can't locate DoesntExist\.pm/,
  "import() fails for inexistent packages";

done_testing;
