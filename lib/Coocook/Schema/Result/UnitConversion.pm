package Coocook::Schema::Result::UnitConversion;

use Moose;
use experimental qw(signatures);
use namespace::autoclean;

extends 'Coocook::Schema::Result';

__PACKAGE__->table('unit_conversions');

__PACKAGE__->add_columns(
    id         => { data_type => 'integer', is_auto_increment => 1 },
    unit1_id   => { data_type => 'integer' },
    factor     => { data_type => 'real' },                              # value1 * factor == value2
    unit2_id   => { data_type => 'integer' },
    transitive => { data_type => 'boolean', default_value => 1 },
    comment    => { data_type => 'text',    default_value => '' },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to( unit1 => 'Coocook::Schema::Result::Unit', 'unit1_id' );
__PACKAGE__->belongs_to( unit2 => 'Coocook::Schema::Result::Unit', 'unit2_id' );

__PACKAGE__->meta->make_immutable;

sub reverse ($self) {
    $self->set_columns(
        {
            unit1_id => $self->unit2_id,
            factor   => 1 / $self->factor,
            unit2_id => $self->unit1_id,
        }
    );

    return $self;
}

1;
