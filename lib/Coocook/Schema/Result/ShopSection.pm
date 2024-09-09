package Coocook::Schema::Result::ShopSection;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::Result';

__PACKAGE__->table('shop_sections');

__PACKAGE__->add_columns(
    id         => { data_type => 'integer', is_auto_increment => 1 },
    project_id => { data_type => 'integer' },
    name       => { data_type => 'text' },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->add_unique_constraints( [ 'project_id', 'name' ] );

__PACKAGE__->belongs_to( project => 'Coocook::Schema::Result::Project', 'project_id' );

__PACKAGE__->has_many(
    articles => 'Coocook::Schema::Result::Article',
    'shop_section_id',
    {
        cascade_delete => 0,    # shop sections with articles may not be deleted
    }
);

__PACKAGE__->meta->make_immutable;

sub deletable ($self) {
    if ( $self->has_column_loaded('articles_count') ) {
        return $self->get_column('articles_count') == 0;
    }
    else {
        return !$self->articles->results_exist;
    }
}

1;
