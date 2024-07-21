package Coocook::Controller::Autocomplete;

use Coocook::Base qw(Moose);

use DateTime;

BEGIN { extends 'Coocook::Controller' }

sub base : Chained('/base') PathPart('autocomplete') CaptureArgs(0) { }

# TODO limit number of results
# TODO sanitize input?
# TODO split words in input
# TODO deterministic sort order?
# TODO rank direct matches first

sub organizations_users : GET HEAD Chained('base') Args(0) Does('~Ajax')
  RequiresCapability('autocomplete_users') {
    my ( $self, $c ) = @_;

    my $search = $c->req->params->get('search');

    my $users = $c->model('Autocomplete')->organizations_users($search);

    if ( not $users ) {
        $c->response->status(400);
        return;
    }

    $c->stash( ajax_response => $users );
}

sub users : GET HEAD Chained('base') Args(0) Does('~Ajax')
  RequiresCapability('autocomplete_organizations') RequiresCapability('autocomplete_users') {
    my ( $self, $c ) = @_;

    my $search = $c->req->params->get('search');

    my $users = $c->model('Autocomplete')->users($search);

    if ( not $users ) {
        $c->response->status(400);
        return;
    }

    $c->stash( ajax_response => $users );
}

__PACKAGE__->meta->make_immutable;

1;
