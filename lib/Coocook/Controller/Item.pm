package Coocook::Controller::Item;

use Coocook::Base qw(Moose);

use DateTime;

BEGIN { extends 'Coocook::Controller' }

=head1 NAME

Coocook::Controller::Items - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub base : Chained('/project/base') PathPart('items') CaptureArgs(1) {
    my ( $self, $c, $item_id ) = @_;

    $c->stash( item => $c->project->purchase_lists->search_related('items')->find($item_id)
          || $c->detach('/error/not_found') );

}

sub convert : POST Chained('base') Args(0) RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $unit = $c->project->units->find( $c->req->params->get('unit') )
      || $c->detach('/error/not_found');

    my $item = $c->stash->{item};
    $item->convert($unit);

    $c->response->redirect(
        $c->project_uri( '/purchase_list/edit', $item->purchase_list_id, \( 'item-' . $item->id ) ) );
}

sub update_offset : POST Chained('base') Args(0) RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $total  = $c->req->params->get('total');
    my $offset = $c->req->params->get('offset');

    ( defined $total xor defined $offset )
      or $c->detach( '/error/bad_request', [] );

    my $item = $c->stash->{item};

    if ( defined $total ) {
        $item->update( { offset => $total - $item->value } );
    }
    elsif ( defined $offset ) {
        $item->update( { offset => $offset } );
    }
    else { die 'Code broken' }

    $c->response->redirect(
        $c->project_uri( '/purchase_list/edit', $item->purchase_list_id, \( 'item-' . $item->id ) ) );
}

__PACKAGE__->meta->make_immutable;

1;
