package Coocook::Base;

# ABSTRACT: base package that enables our common Perl pragmas

use strict;
use warnings;
no warnings qw(experimental::signatures);
use feature qw(signatures);

use Carp;
use Module::Load;

our $DEBUG //= $ENV{COOCOOK_BASE_DEBUG};

=head1 Coocook::Base

=head2 Synopsis

    package Coocook::MyModule;

    use Coocook::Base;    # this shall come first, it enables our set of pragmas

    use Carp;             # other modules you want to use

    sub foo ($bar) {      # you can use signatures for example
        ...

=head2 What this does

Using this module is equivalent to:

    use strict;
    use warnings;
    use utf8;
    use feature qw( :5.32 signatures );
    no  feature qw( indirect );
    no warnings qw( experimental::signatures );

=head2 Moose

Unfortunately L<Moose> unconditionally enables I<all> warnings,
including C<experimental::signatures>.
To circumvent this additional packages can be loaded
by providing them as an argument list to C<use>.
This is required for L<Moose> and its subclasses.
For these packages L<namespace::autoclean> is automatically
imported as well.

    use Coocook::Base qw( Moose MooseX::NonMoose );

This will import all named packages into the calling namespace
and afterwards set up pragmas as described above.
It is roughly equivalent to the following but without
worrying about the correct order of package names:

    use Moose;
    use MooseX::NonMoose;
    use namespace::autoclean;
    use Coocook::Base;

=cut

sub import ( $class, @packages ) {
    my $uses_moose;

    for my $package (@packages) {
        load $package;

        if ( $package =~ m/Moose/ ) {    # Moose modules need this quirk
            $uses_moose = 1;

            $DEBUG and warn sprintf "$package->import( { into => %s } )", (caller)[0];
            $package->import( { into => caller() } );
        }
        else {
            $DEBUG and warn "$package->import()";
            $package->import();
        }
    }

    if ($uses_moose) {
        $DEBUG and warn "namespace::autoclean->import()";
        namespace::autoclean->import;
    }
    else {
        strict->import;
        warnings->import;
    }

    # this must be done after import of @packages like Moose
    warnings->unimport(qw( experimental::signatures ));

    feature->import(qw( :5.32 signatures ));
    feature->unimport(qw( indirect ));
    utf8->import;
}

1;
