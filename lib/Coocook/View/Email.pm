package Coocook::View::Email;

# ABSTRACT: create emails with TT templates and Email::Stuffer

use Coocook::Base;
use Moose;
use MooseX::NonMoose;
use namespace::autoclean;

use Email::Stuffer;

extends 'Catalyst::View';

=head1 NAME

Coocook::View::Email - Catalyst View

=head1 DESCRIPTION

Catalyst View.

=cut

sub process ( $self, $c, @args ) {
    my $stash = $c->stash->{email};

    # automatically set template filename based on action path
    $stash->{template} ||= do {
        my $action = $c->action;
        $action =~ s!^email/!!
          or warn "Unexpected action '$action'";

        $action . '.tt';
    };

    my $body = $c->view('Email::TT')->render( $c, $stash->{template}, $c->stash );

    Email::Stuffer->from( $stash->{from} )->to( $stash->{to} )->subject( $stash->{subject} )
      ->text_body($body)->send;
}

__PACKAGE__->meta->make_immutable;

1;
