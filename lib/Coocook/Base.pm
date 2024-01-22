package Coocook::Base;

# ABSTRACT: base package that enables our common Perl pragmas

use strict;
use warnings;
no warnings qw(experimental::signatures);
use feature qw(signatures);

use Carp;
use Module::Load;

our $DEBUG //= $ENV{COOCOOK_BASE_DEBUG};

my %needs_into_caller = map { $_ => 1 } qw(
  Moose
  Moose::Role
  MooseX::NonMoose
);

sub import ( $class, @packages ) {
    my $uses_moose;

    for (@packages) {
        if (/Moose/) {
            $uses_moose = 1;
        }

        load $_;

        if ( $needs_into_caller{$_} ) {
            $DEBUG and warn sprintf "${_}->import( { into => %s } )", (caller)[0];
            $_->import( { into => caller() } );
        }
        else {
            $DEBUG and warn "${_}->import()";
            $_->import();
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
