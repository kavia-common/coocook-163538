package Coocook::Base;

# ABSTRACT: base package that enables our common Perl pragmas

use strict;
use warnings;
no warnings qw(experimental::signatures);
use feature qw(signatures);

use Carp;

sub import ( $class, @features ) {
    my $moose;
    my $moose_role;
    my $moosex_nonmoose;

    for (@features) {
        my %features = (
            'Moose'            => sub { $moose           = 1 },
            'Moose::Role'      => sub { $moose_role      = 1 },
            'MooseX::NonMoose' => sub { $moosex_nonmoose = 1 },
        );
        my $croak = sub { croak "Invalid feature for " . __PACKAGE__ };

        ( $features{$_} || $croak )->();
    }

    if ( $moose or $moose_role or $moosex_nonmoose ) {
        require Moose;
        require MooseX::NonMoose if $moosex_nonmoose;
        require namespace::autoclean;

        if ($moose_role) {
            require Moose::Role;
            Moose::Role->import( { into => caller() } );
        }
        else {
            Moose->import( { into => caller() } );
        }
        MooseX::NonMoose->import( { into => caller() } ) if $moosex_nonmoose;
        namespace::autoclean->import;
    }
    else {
        strict->import;
        warnings->import;
    }

    warnings->unimport(qw( experimental::signatures ));

    feature->import(qw( fc say signatures :5.32 ));
    feature->unimport(qw( indirect ));
    utf8->import;
}

1;
