use Coocook::Base;

use Carp;
use Test2::V0;
use Test::Builder;

use lib "t/lib";
use TestDB qw(txn_do_and_rollback);

my $db             = TestDB->new();
my $project        = $db->resultset('Project')->find(1);
my $units          = $project->units;
my $purchase_lists = $project->purchase_lists;
my $ingredients    = $project->dishes->search_related('ingredients');
our $items = $project->items;

# declare names to allow to call these functions without parenthesis
sub items_ingredients_are;
sub set_items_ingredients;
sub t;

items_ingredients_are [
    "14.5+0kg: 500g 0.5kg 1kg 12.5kg",
    "42.5+7.5g: 5g 12.5g 25g",
    "500+0g: 500g",
    "1.75+0l: 0.5l 0.25l 1l",
  ],
  "items_ingredients_are() helper function";

subtest "delete dish" => txn_do_and_rollback $db => sub {
    ok $project->dishes->find(1)->delete_update_items();

    items_ingredients_are [
        "14+0kg: 0.5kg 1kg 12.5kg",    #perltidy
        "37.5+0g: 12.5g 25g",
        "500+0g: 500g",
        "1.25+0l: 0.25l 1l",
    ];
};

subtest "move ingredient to other purchase list" => sub {
    my $list1 = $purchase_lists->find(1);
    my $list2 = $purchase_lists->find(2);

    ok $list1->move_items_ingredients(
        target_purchase_list => $list2,
        ingredients          => [ $ingredients->find(1), $ingredients->find(2) ],
        items                => [ $items->find(4) ],
        ucg                  => $project->unit_conversion_graph,
    );

    local $items = $list1->items;
    items_ingredients_are [
        "14+0kg: 0.5kg 1kg 12.5kg",    # item 1 with 500g removed
        "37.5+0g: 12.5g 25g",          # item 1 with 5g removed
    ];

    local $items = $list2->items;
    items_ingredients_are bag {        # order of items after operation unstable
        item "1.75+0l: 0.5l 0.25l 1l";    # was already on $list2
        item "500+0g: 500g";              # removed item 4
        item "500+0g: 500g";              # removed ingredient 1 from item 1
        item "5+0g: 5g";                  # removed ingredient 2 from item 2
        end;
    };
};

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
    t "12-2g: 12g", sub { $_->set_value_update_item(9) }  => "9+0g: 9g";
    t "12-2g: 12g", sub { $_->set_value_update_item(10) } => "10+0g: 10g";
    t "12-2g: 12g", sub { $_->set_value_update_item(11) } => "11-1g: 11g";
    t "12-2g: 12g", sub { $_->set_value_update_item(12) } => "12-2g: 12g";
    t "12-2g: 12g", sub { $_->set_value_update_item(13) } => "13+0g: 13g";
    t "12-2g: 12g", sub { $_->set_value_update_item(14) } => "14+0g: 14g";
    t "12-2g: 12g", sub { $_->set_value_update_item(15) } => "15+0g: 15g";

    t "10+0g: 10g", sub { $_->set_value_update_item(9) }  => "9+0g: 9g";
    t "10+0g: 10g", sub { $_->set_value_update_item(10) } => "10+0g: 10g";
    t "10+0g: 10g", sub { $_->set_value_update_item(11) } => "11+0g: 11g";

    t "8+2g: 8g", sub { $_->set_value_update_item(5) }  => "5+0g: 5g";
    t "8+2g: 8g", sub { $_->set_value_update_item(6) }  => "6+0g: 6g";
    t "8+2g: 8g", sub { $_->set_value_update_item(7) }  => "7+0g: 7g";
    t "8+2g: 8g", sub { $_->set_value_update_item(8) }  => "8+2g: 8g";
    t "8+2g: 8g", sub { $_->set_value_update_item(9) }  => "9+1g: 9g";
    t "8+2g: 8g", sub { $_->set_value_update_item(10) } => "10+0g: 10g";
    t "8+2g: 8g", sub { $_->set_value_update_item(11) } => "11+0g: 11g";

    like dies { $ingredients->one_row->set_value_update_item(-1) } => qr/negative/i,
      "exception for negative value";
};

subtest "update ingredient value and unit" => sub {
    my ( $g, $kg, $l, $p ) = map { $units->find( { short_name => $_ } )->id } qw( g kg l p );

    t "1g", sub { $_->set_value_unit_update_item( 2, $kg ) } => "2kg", "ingredient without item";

    t "1+0kg: 1kg", sub { $_->set_value_unit_update_item( 500, $g ) } => "0.5+0kg: 500g",
      "basic item with conversion";

    t "1+0kg: 1kg", sub { $_->set_value_unit_update_item( 0.5, $l ) } => "0.5+0l: 0.5l",
      "basic item without conversion";

    t "2+0kg: 1kg 1000g", sub { $_->set_value_unit_update_item( 500, $g ) } => "1.5+0kg: 500g 1000g",
      "item with two ingredients";

    t "2+0kg: 1kg 1000g",
      sub { $_->set_value_unit_update_item( 0.5, $l ) } => [ "1+0kg: 1000g", "0.5+0l: 0.5l" ],
      "kg to liter";

    t "2+0kg: 1l 1000g",
      sub { $_->set_value_unit_update_item( 500, $g ) } => [ "1+0kg: 1000g", "500+0g: 500g" ],
      "liter to grams";

    t "2+0kg: 1l 1000g",
      sub { $_->set_value_unit_update_item( 500, $p ) } => [ "1+0kg: 1000g", "500+0p: 500p" ],
      "liter to pinch";
};

subtest "delete ingredient" => sub {
    t "1g", sub { !$_->delete_update_item } => [], "ingredients without item";

    t "3+0g: 1g 2g", sub { $_->delete_update_item } => "2+0g: 2g", "basic item";

    t "1+0g: 1g", sub { !$_->delete_update_item } => [], "item got deleted";

    t "0+0g: 0g", sub { !$_->delete_update_item } => [], "zero item got deleted";

    t "0+0kg: 0g", sub { !$_->delete_update_item } => [], "zero item with conversion got deleted";

    t "900+100g: 400g 500g", sub { $_->delete_update_item } => "500+0g: 500g", "removed offset";

    t "1200-200g: 100g 1100g", sub { $_->delete_update_item } => "1100-100g: 1100g", "reduced offset";

    t "2+0.1kg: 400g 600g 1l 3p", sub { $_->delete_update_item } => "1.6+0kg: 600g 1l 3p",
      "subtracted from total, cleared offset";

    t "1+0kg: 0p 1kg", sub { $_->delete_update_item } => "1+0kg: 1kg",
      "remove zero ingredient without factor";

    t "2+0.1kg: 1l 0.6kg 400g 3p",
      sub { $_->delete_update_item } => [ "1+0kg: 0.6kg 400g", "3+0p: 3p" ],
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

    my @ingredients;

    for (@strings) {
        my ( $item_string, $ingredients_string ) = m/^(?<item>.+): (?<ingredients>.+)$/;

        if ( not $item_string ) {
            m/^ (?<value>[0-9.]+) (?<unit>\w+) $/x
              or croak "invalid item/ingredient: '$_'";

            push @ingredients,
              $ingredients->create(
                {
                    dish_id    => 1,
                    item_id    => undef,
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

        push @ingredients, $item->ingredients->populate(
            [
                map {
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
                } split( / /, $ingredients_string )
            ]
        );
    }

    return @ingredients;
}

sub t ( $input, $coderef, $expected, $name = undef ) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my @ingredients = set_items_ingredients( ref $input eq 'ARRAY' ? @$input : $input );
    local $_ = $ingredients[0];
    my $coderef_ok = $coderef->(@ingredients) or fail $name;
    items_ingredients_are(
        ref $expected eq 'ARRAY' ? $expected : [$expected],
        $coderef_ok              ? $name     : "... items_ingredients_are()"
    );
}
