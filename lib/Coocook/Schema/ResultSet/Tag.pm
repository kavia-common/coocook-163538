package Coocook::Schema::ResultSet::Tag;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::ResultSet';

__PACKAGE__->load_components('+Coocook::Schema::Component::ResultSet::SortByName');

sub joined ($self) {
    return join ", ", $self->get_column('name')->all;
}

sub from_names ( $self, $str ) {
    my @names = split qr/,\s+/, $str;

    return $self->search(
        {
            $self->me('name') => { -in => \@names },
        }
    );
}

sub ungrouped ($self) {
    return $self->search( { $self->me('tag_group') => undef } );
}

__PACKAGE__->meta->make_immutable;

1;
