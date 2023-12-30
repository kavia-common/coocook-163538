use Test2::V0;

use lib 't/lib';
use TestDB;

plan(5);

subtest "ResultSet::Unit->in_use()" => sub {
    my $db = TestDB->new;

    is join( ',', sort $db->resultset('Unit')->in_use->get_column('short_name')->all ) => 'g,kg,l',
      "with units";

    is
      join( ',',
        sort $db->resultset('Article')->find(1)->units->in_use->get_column('short_name')->all ) => 'g,kg',
      "only units belonging to 1 article";

    is
      join( ',',
        sort $db->resultset('Article')->find(4)->units_in_use->get_column('short_name')->all ) => 'g',
      "units belonging to 1 article when not all are in use";

    $db->resultset($_)->delete for qw< DishIngredient RecipeIngredient Item >;

    is join( ',', $db->resultset('Unit')->in_use->get_column('short_name')->all ) => '',
      "without any used units";
};

my $db = TestDB->new;

subtest "ResultSet::Unit->with_number_of_ingredients_items" => sub {
    ok my @units = $db->resultset('Unit')->with_number_of_ingredients_items->hri->all;

    like \@units => bag {
        item hash {
            field id                           => 1;
            field number_of_dish_ingredients   => 5;
            field number_of_recipe_ingredients => 2;
            field number_of_items              => 2;
        };
        item hash {
            field id                           => 2;
            field number_of_dish_ingredients   => 3;
            field number_of_recipe_ingredients => 1;
            field number_of_items              => 0;
        };
        item hash {
            field id                           => 3;
            field number_of_dish_ingredients   => 3;
            field number_of_recipe_ingredients => 1;
            field number_of_items              => 0;
        };
    };
};

my $kg = $db->resultset('Unit')->find( { short_name => 'kg' } );

is join( ',', sort map { $_->short_name } $kg->convertible_into ) => 'g,t',
  "is convertible_into g and t";

like dies { $kg->delete }, qr/FOREIGN KEY constraint failed/, "fails while rows reference unit";

note "deleting referencing rows ...";
$db->resultset($_)->delete for qw<
  DishIngredient
  Item
  RecipeIngredient
  ArticleUnit
>;

$kg->conversions->count > 0 or die "no conversions";

ok $kg->delete, "delete unit that has conversions";
