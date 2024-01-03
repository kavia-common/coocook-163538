package Coocook::Schema::Result::PurchaseList;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::Result';

__PACKAGE__->table('purchase_lists');

__PACKAGE__->add_columns(
    id         => { data_type => 'integer', is_auto_increment => 1 },
    project_id => { data_type => 'integer' },
    name       => { data_type => 'text' },
    date       => { data_type => 'date' },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->add_unique_constraints( [qw<project_id name>] );

__PACKAGE__->belongs_to( project => 'Coocook::Schema::Result::Project', 'project_id' );

__PACKAGE__->has_many(
    items => 'Coocook::Schema::Result::Item',
    'purchase_list_id'
);

__PACKAGE__->many_to_many( articles => items => 'article' );
__PACKAGE__->many_to_many( units    => items => 'unit' );

__PACKAGE__->has_many(
    other_purchase_lists => __PACKAGE__,
    sub ($args) {
        return {
            "$args->{foreign_alias}.id"         => { '!='   => { -ident => "$args->{self_alias}.id" } },
            "$args->{foreign_alias}.project_id" => { -ident => "$args->{self_alias}.project_id" },
        };
    }
);

__PACKAGE__->meta->make_immutable;

sub is_default ($self) {
    if ( $self->has_column_loaded('is_default') ) {    # extra column from RS->with_is_default()
        return $self->get_column('is_default');
    }
    else {
        return (
            ( $self->project->default_purchase_list_id // die 'project has no default_purchase_list_id' ) ==
              $self->id );
    }
}

sub make_default ($self) {
    $self->project->update( { default_purchase_list_id => $self->id } );

    return $self;
}

1;
