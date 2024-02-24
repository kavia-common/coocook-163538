use Test2::V0;

use Coocook::Model::UnitConversionGraph;

use lib "t/lib";
use TestDB;

my $schema = TestDB->new;

ok my $graph = Coocook::Model::UnitConversionGraph->new( $schema->resultset('UnitConversion') );

is [ sort $graph->unit_convertible_into(1) ]    # grams
  => [
    2,                                          # kg
    4,                                          # tons
  ],
  "unit_convertible_into()";

subtest "can_convert()" => sub {
    ok $graph->can_convert( 1  => 2 ), "g->kg";
    ok $graph->can_convert( 2  => 1 ), "kg->g (opposite direction)";
    ok $graph->can_convert( 1  => 4 ), "g->t";
    ok $graph->can_convert( 4  => 1 ), "t->g (opposite direction)";
    ok !$graph->can_convert( 1 => 3 ), "can't g->l";
};

subtest "factor_between_units()" => sub {
    is $graph->factor_between_units( 1, 1 ) => 1,     "conversion to same unit";
    is $graph->factor_between_units( 1, 3 ) => undef, "impossible conversion (g->l)";

    is $graph->factor_between_units( 1, 2 ) => 0.001, "g->kg";
    is $graph->factor_between_units( 2, 1 ) => 1_000, "kg->g";

    is $graph->factor_between_units( 1, 4 ) => 0.000_001, "g->t";
    is $graph->factor_between_units( 4, 1 ) => 1_000_000, "t->g";
};

done_testing;
