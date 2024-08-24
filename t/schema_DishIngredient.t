use Coocook::Base;

use Carp;
use Test2::V0;
use Test::Builder;

use lib "t/lib";
use TestDB;

my $db          = TestDB->new();
my $project     = $db->resultset('Project')->find(1);
my $units       = $project->units;
my $items       = $project->items;
my $ingredients = $project->dishes->search_related('ingredients');

# declare names to allow to call these functions without parenthesis
sub items_ingredients_are;
sub set_items_ingredients;

items_ingredients_are [
    "14.5+0kg: 500g 0.5kg 1kg 12.5kg",
    "42.5+7.5g: 5g 12.5g 25g",
    "1.75+0l: 0.5l 0.25l 1l",
    "500+0g: 500g",
  ],
  "items_ingredients_are() helper function";

{
    ok set_items_ingredients(
        my @set = (
            "1+0l: 1l",               # simple
            "1+0kg: 0.5kg 500g",      # two units
            "900+100g: 500g 400g",    # offset
            "42+8p: 1g 1kg 1l",       # completely wild
            "42g",                    # ingredient without item
        )
      ),
      "set_items_ingredients() helper function";

    items_ingredients_are \@set, "... expected result";
}

subtest "update ingredient value" => sub {
    my $test = sub ( $value1, $offset1, $delta, $value2, $offset2 ) {
        local $Test::Builder::Level = $Test::Builder::Level + 1;

        set_items_ingredients $value1 . ( $offset1 >= 0 ? '+' : '' ) . "${offset1}g: ${value1}g";
        ok $ingredients->one_row->set_value_update_item( $value1 + $delta );
        items_ingredients_are [ $value2 . ( $offset2 >= 0 ? '+' : '' ) . "${offset2}g: ${value2}g" ];
    };

    # offset/value => delta => offset/value
    $test->( 12, -2 => -3 => 9,  +0 );
    $test->( 12, -2 => -2 => 10, +0 );
    $test->( 12, -2 => -1 => 11, -1 );
    $test->( 12, -2 => +0 => 12, -2 );
    $test->( 12, -2 => +1 => 13, +0 );
    $test->( 12, -2 => +2 => 14, +0 );
    $test->( 12, -2 => +3 => 15, +0 );

    $test->( 10, +0 => -1 => 9,  +0 );
    $test->( 10, +0 => +0 => 10, +0 );
    $test->( 10, +0 => +1 => 11, +0 );

    $test->( 8, +2 => -3 => 5,  +0 );
    $test->( 8, +2 => -2 => 6,  +0 );
    $test->( 8, +2 => -1 => 7,  +0 );
    $test->( 8, +2 => +0 => 8,  +2 );
    $test->( 8, +2 => +1 => 9,  +1 );
    $test->( 8, +2 => +2 => 10, +0 );
    $test->( 8, +2 => +3 => 11, +0 );

    like dies { $ingredients->one_row->set_value_update_item(-1) } => qr/negative/i,
      "exception for negative value";
};

subtest "update ingredient value and unit" => sub {
    my ( $g, $kg, $l, $p ) = map { $units->find( { short_name => $_ } )->id } qw( g kg l p );

    set_items_ingredients "1g";
    ok $ingredients->find( { value => 1 } )->set_value_unit_update_item( 2, $kg );
    items_ingredients_are ["2kg"], "ingredient without item";

    set_items_ingredients "1+0kg: 1kg";
    ok $ingredients->find( { value => 1 } )->set_value_unit_update_item( 500, $g );
    items_ingredients_are ["0.5+0kg: 500g"], "basic item with conversion";

    set_items_ingredients "1+0kg: 1kg";
    ok $ingredients->find( { value => 1 } )->set_value_unit_update_item( 0.5, $l );
    items_ingredients_are ["0.5+0l: 0.5l"], "basic item without conversion";

    set_items_ingredients "2+0kg: 1kg 1000g";
    ok $ingredients->find( { value => 1 } )->set_value_unit_update_item( 500, $g );
    items_ingredients_are ["1.5+0kg: 500g 1000g"], "item with two ingredients";

    set_items_ingredients "2+0kg: 1000g 1kg";
    ok $ingredients->find( { value => 1 } )->set_value_unit_update_item( 0.5, $l );
    items_ingredients_are [ "1+0kg: 1000g", "0.5+0l: 0.5l" ], "kg to liter";

    set_items_ingredients "2+0kg: 1000g 1l";
    ok $ingredients->find( { value => 1 } )->set_value_unit_update_item( 500, $g );
    items_ingredients_are [ "1+0kg: 1000g", "500+0g: 500g" ], "liter to grams";

    set_items_ingredients "2+0kg: 1000g 1l";
    ok $ingredients->find( { value => 1 } )->set_value_unit_update_item( 500, $p );
    items_ingredients_are [ "1+0kg: 1000g", "500+0p: 500p" ], "liter to pinch";
};

todo TODO => sub {
    subtest "move ingredient to other purchase list" => sub {

    };
};

subtest "delete ingredient" => sub {
    set_items_ingredients "1g";
    ok !$ingredients->find( { value => 1 } )->delete_update_item();
    items_ingredients_are [], "ingredient without item";

    set_items_ingredients "3+0g: 1g 2g";
    ok $ingredients->find( { value => 1 } )->delete_update_item();
    items_ingredients_are ["2+0g: 2g"], "basic item";

    set_items_ingredients "1+0g: 1g";
    ok !$ingredients->find( { value => 1 } )->delete_update_item();
    items_ingredients_are [], "item got deleted";

    set_items_ingredients "0+0g: 0g";
    ok !$ingredients->find( { value => 0 } )->delete_update_item();
    items_ingredients_are [], "zero item got deleted";

    set_items_ingredients "0+0kg: 0g";
    ok !$ingredients->find( { value => 0 } )->delete_update_item();
    items_ingredients_are [], "zero item with conversion got deleted";

    set_items_ingredients "900+100g: 500g 400g";
    ok $ingredients->find( { value => 400 } )->delete_update_item();
    items_ingredients_are ["500+0g: 500g"], "removed offset";

    set_items_ingredients "1200-200g: 1100g 100g";
    ok $ingredients->find( { value => 100 } )->delete_update_item();
    items_ingredients_are ["1100-100g: 1100g"], "reduced offset";

    set_items_ingredients "2+0.1kg: 600g 400g 1l 3p";
    ok $ingredients->find( { value => 400 } )->delete_update_item();
    items_ingredients_are ["1.6+0kg: 600g 1l 3p"], "subtracted from total, cleared offset";

    set_items_ingredients "1+0kg: 1kg 0p";
    ok $ingredients->find( { value => 0 } )->delete_update_item();
    items_ingredients_are ["1+0kg: 1kg"], "remove zero ingredient without factor";

    set_items_ingredients "2+0.1kg: 0.6kg 400g 1l 3p";
    ok $ingredients->find( { value => 1 } )->delete_update_item();
    items_ingredients_are [ "1+0kg: 0.6kg 400g", "3+0p: 3p" ],
      "recalculated from ingredients, split item";
};

done_testing;

sub items_ingredients_are ( $expected, $name = undef ) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my @items;

    for my $item ( $items->all ) {
        push @items,
            $item->value
          . ( $item->offset >= 0 ? '+' : '' )
          . $item->offset
          . $item->unit->short_name . ": "
          . join " ", map { $_->value . $_->unit->short_name } $item->ingredients->all;
    }

    push @items, map { $_->value . $_->unit->short_name } $ingredients->unassigned->all;

    is \@items => $expected, $name;
}

sub set_items_ingredients (@strings) {
    $items->delete();
    $ingredients->delete();

    for (@strings) {
        my ( $item_string, $ingredients_string ) = m/^(?<item>.+): (?<ingredients>.+)$/;

        if ( not $item_string ) {
            m/^ (?<value>[0-9.]+) (?<unit>\w+) $/x
              or croak "invalid item/ingredient: '$_'";

            $ingredients->create(
                {
                    dish_id    => 1,
                    prepare    => 0,
                    value      => $+{value},
                    unit_id    => $units->find( { short_name => $+{unit} } )->id,
                    article_id => 1,
                    comment    => '',
                }
            );

            next;
        }

        $item_string =~ m/^ (?<value>[0-9.]+) (?<offset>[+-] [0-9.]+) (?<unit>\w+) $/x
          or croak "invalid item: '$item_string'";

        my $item = $items->create(
            {
                value            => $+{value},
                offset           => $+{offset},
                article_id       => 1,
                unit_id          => $units->find( { short_name => $+{unit} } )->id,
                purchase_list_id => 1,
                comment          => '',
            }
        );

        my @ingredients = map {
            m/^ (?<value>[0-9.]+) (?<unit>\w+) $/x
              or croak "invalid ingredient: '$_'";

            my $unit_id = $units->find( { short_name => $+{unit} } )->id;
            {
                dish_id    => 1,
                prepare    => 0,
                value      => $+{value},
                unit_id    => $unit_id,
                article_id => 1,
                comment    => '',
            }

        } split / /, $ingredients_string;

        $item->ingredients->populate( \@ingredients );

    }

    return 1;
}
