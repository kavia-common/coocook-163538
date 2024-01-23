use Coocook::Base;
use Test2::V0;

use URI;

{

    package PkgWithoutMoose;    ## no critic (RequireFilenameMatchesPackage)

    use Coocook::Base;
    use Carp;

    sub f ($x) { carp $x }
}

{

    package PkgWithMoose;

    use Coocook::Base qw( Moose MooseX::NonMoose );
    use Carp;

    sub f ( $self, $x ) { carp $x }

    __PACKAGE__->meta->make_immutable;
}

subtest PkgWithoutMoose => sub {
    like warning { PkgWithoutMoose::f('foo') } => qr/^foo /, "PkgWithoutMoose->f() does carp()";
    ok defined &PkgWithoutMoose::carp,  "used carp() from Carp hasn't been cleaned";
    ok defined &PkgWithoutMoose::croak, "unused croak() from Carp hasn't been cleaned";
    ok !defined &PkgWithoutMoose::meta, "package has no meta() from Moose";
};

subtest PkgWithMoose => sub {
    like warning { PkgWithMoose->new->f('bar') } => qr/^bar /, "PkgWithMoose->f() does carp()";
    ok !defined &PkgWithMoose::croak, "unused croak() from Carp has been cleaned";
    ok defined &PkgWithMoose::meta,   "package has meta() from Moose";
};

like dies { Coocook::Base->import(qw( Carp DoesntExist )) } => qr/Can't locate DoesntExist\.pm/,
  "import() fails for inexistent packages";

subtest "indirect object syntax" => sub {
    my $code = "new URI()";

    ## we need stringy eval here to test invalid syntax ...
    ## no critic (BuiltinFunctions::ProhibitStringyEval)

    # TODO reduce warnings category to 'bareword'
    # https://github.com/Perl/perl5/issues/21878
    like do { no warnings qw(syntax); eval $code; $@ }
      => qr/syntax error/;

    use feature qw(indirect);         # the effect of this is not block-scoped->last in this file
    isa_ok( eval $code => 'URI' );    # countercheck: same code works with syntax enabled
};

done_testing;
