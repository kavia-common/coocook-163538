package Coocook::Schema::ResultSet;

# ABSTRACT: base class for all ResultSet classes

use Coocook::Base qw( Moose MooseX::NonMoose );

use Carp;

our @CARP_NOT;

extends 'DBIx::Class::ResultSet';

__PACKAGE__->load_components(
    qw<
      +Coocook::Schema::Component::ProxyMethods
      Helper::ResultSet::CorrelateRelationship
      Helper::ResultSet::IgnoreWantarray
      Helper::ResultSet::Me
      Helper::ResultSet::OneRow
      Helper::ResultSet::Random
      Helper::ResultSet::SetOperations
      Helper::ResultSet::Shortcut::ResultsExist
      Helper::ResultSet::Shortcut::HRI
    >
);

# discourage use of first(), except for Catalyst::Auth::Store::DBIC (upstream code)
before first => sub {
    if ( my $caller = caller(2) ) {
        return if $caller eq 'Catalyst::Authentication::Store::DBIx::Class::User';
    }

    local @CARP_NOT = 'Class::MOP::Method::Wrapped';

    croak "You probably want next(), one_row() or single()";
};

__PACKAGE__->meta->make_immutable;

# from https://metacpan.org/pod/release/MSTROUT/DBIx-Class-0.08100/lib/DBIx/Class/Manual/Cookbook.pod#SELECT-COUNT(DISTINCT-colname)
sub count_distinct ( $self, $column ) {
    return $self->search( undef, { columns => { count => { COUNT => { DISTINCT => $column } } } } )
      ->hri->one_row->{count};
}

=head2 only_id_col($id_column_name?)

Returns new resultset with only the column 'id' selected.

=cut

sub only_id_col ( $self, $id_column_name = 'id' ) {
    return $self->search( undef, { columns => [$id_column_name] } );
}

# Check if DBIx::Class::Storage::DBI::Cursor already has a statement handle
sub assert_no_sth ($self) {
    defined( $self->cursor->{sth} ) and croak "Statement already running";
}

1;
