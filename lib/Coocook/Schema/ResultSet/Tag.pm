package Coocook::Schema::ResultSet::Tag;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::ResultSet';

__PACKAGE__->load_components('+Coocook::Schema::Component::ResultSet::SortByName');

sub joined ($self) {
    return join ", ", $self->sorted->get_column('name')->all;
}

sub find_or_create_from_names ( $self, $str ) {
    my @names = split qr/,\s+/, $str;

    my $existing_rs = $self->search(
        {
            $self->me('name') => { -in => \@names }
        }
    );

    my %existing_names = map  { $_->name => 1 } $existing_rs->all;
    my @new_names      = grep { !$existing_names{$_} } @names;

    foreach my $name (@new_names) {
        $self->create( { name => $name } );
    }

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
