package Coocook::Model::UnitConversionGraph;

# ABSTRACT: representation of connections between a set of units for conversion

use Coocook::Base;

use Graph::Directed;
use Graph::TransitiveClosure::Matrix;

sub new ( $class, $conversions_rs ) {
    my $graph = Graph::Directed->new();

    $conversions_rs = $conversions_rs->search( undef, { columns => [qw( unit1_id factor unit2_id )] } );

    while ( my $conversion = $conversions_rs->next ) {
        $graph->set_edge_attribute(
            $conversion->unit1_id => $conversion->unit2_id,
            factor                => $conversion->factor
        );
        $graph->set_edge_attribute(
            $conversion->unit2_id => $conversion->unit1_id,
            factor                => 1 / $conversion->factor
        );
    }

    my $tcm = Graph::TransitiveClosure::Matrix->new(
        $graph,
        attribute_name => 'factor',
        path_vertices  => 1,
    );

    return bless [ $graph, $tcm ], ref $class || $class;
}

# getters
sub graph ($self) { $self->[0] }
sub tcm   ($self) { $self->[1] }

sub factor_between_units ( $self, $unit1_id, $unit2_id ) {
    $unit1_id == $unit2_id and return 1;

    my @units = $self->tcm->path_vertices( $unit1_id, $unit2_id )
      or return;

    # TCM->path_length() adds factors like 1000 + 1000 = 2000 instead of multiplying:-(
    # Need to calculate factor ourselves ...
    my $factor = 1;
    do {
        $factor *= $self->graph->get_edge_attribute( @units[ 0, 1 ], 'factor' );
        shift @units;
    } while ( @units >= 2 );

    return $factor;
}

sub can_convert ( $self, $unit1_id, $unit2_id ) {
    return $self->tcm->is_reachable( $unit1_id => $unit2_id );
}

sub unit_convertible_into ( $self, $unit_id ) {
    return $self->graph->all_neighbors($unit_id);
}

1;
