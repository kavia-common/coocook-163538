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

    $c->stash( item => $c->project->purchase_lists->find_related( items => $item_id )
          || $c->detach('/error/not_found') );

}

sub convert : POST Chained('base') Args(0) RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $unit = $c->project->units->find( $c->req->params->get('unit') )
      || $c->detach('/error/not_found');

    my $new_total = $c->req->params->get('total') // $c->detach('/error/bad_request');

    my $item = $c->stash->{item};
    my $ucg  = $c->project->unit_conversion_graph;

    # TODO This logic could be capsuled inside Result::Item
    #      if model classes could raise a user error message,
    #      e.g. with some custom exception class
    my $factor = $ucg->factor_between_units( $item->unit_id => $unit->id )
      or $c->detach( '/error/bad_request', ["No conversion factor known to requested unit."] );

    # difference between new total sent by browser and new total calculated now
    # -> item or conversion has been modified since user received HTML form
    my $abs_difference = abs( $new_total - $item->total * $factor );

    # can't use numerical equivalence with == because of floating point math!
    if ( $new_total <= 0 or $abs_difference > 0.0001 ) {
        $c->detach('/error/bad_request');
    }

    my $new_item = $item->change_value_offset_unit(
        $item->value * $factor,    #perltidy
        $item->offset * $factor,
        $unit->id
    );

    $c->response->redirect(
        $c->project_uri( '/purchase_list/edit', $item->purchase_list_id, \( 'item-' . $new_item->id ) ) );
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
