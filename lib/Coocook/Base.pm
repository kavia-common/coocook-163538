package Coocook::Base;

# ABSTRACT: base package that enables our common Perl pragmas

use strict;
use warnings;
use feature ();

sub import {
    strict->import;
    warnings->import;
    warnings->unimport(qw( experimental::signatures ));

    feature->import(qw( fc say signatures :5.32 ));
    feature->unimport(qw( indirect ));
    utf8->import;
}

1;
