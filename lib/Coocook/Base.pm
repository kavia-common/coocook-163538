package Coocook::Base;

# ABSTRACT: base package that enables our common Perl pragmas

use strict;
use warnings;
no warnings qw(experimental::signatures);
use feature qw(signatures);

use Carp;
use Module::Load;

our $DEBUG //= $ENV{COOCOOK_BASE_DEBUG};

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

    feature->import(qw( fc say signatures :5.32 ));
    feature->unimport(qw( indirect ));
    utf8->import;
}

1;
