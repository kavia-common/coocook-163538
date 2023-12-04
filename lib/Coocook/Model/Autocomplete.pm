package Coocook::Model::Autocomplete;

# ABSTRACT: provide data to autocomplete HTML input elements

use Coocook::Base;
use Moose;

extends 'Catalyst::Model';

has schema => (
    is  => 'rw',
    isa => 'Coocook::Schema',
);

__PACKAGE__->meta->make_immutable;

# TODO this is called once per request. can we get $schema once for all?
sub ACCEPT_CONTEXT ( $self, $c, @args ) {
    $self->schema( $c->model('DB')->schema );

    return $self;
}

sub organizations_users ( $self, $search ) {
    my $arrayref = $self->users($search);
    $_->{type} = 'user' for @$arrayref;

    my $organizations = $self->schema->resultset('Organization')->search(
        {
            -or => [
                name         => { like => "%$search%" },
                display_name => { like => "%$search%" },
            ],
        }
    );

    push @$arrayref,
      map { $_->{type} = 'organization'; $_ }
      $organizations->search( undef, { columns => [ 'name', 'display_name' ] } )->hri->all;

    return $arrayref;
}

sub users ( $self, $search ) {
    my $users = $self->schema->resultset('User')->search(
        {
            -or => [
                name         => { like => "%$search%" },
                display_name => { like => "%$search%" },
            ],
        }
    );

    return [ $users->search( undef, { columns => [ 'name', 'display_name' ] } )->hri->all ];
}

1;
