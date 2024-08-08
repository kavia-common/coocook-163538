use Test2::V0;

use DateTime;

use lib 't/lib';
use Test::Coocook;

#plan(41);

my $t = Test::Coocook->new();

$t->get_ok('/');
$t->login_ok( 'john_doe', 'P@ssw0rd' );

#ok $t->post('/project/1/Test-Project/move_meal_dish'), "empty request";
#$t->status_is(400);

ok $t->post_json(
    'https://localhost/project/1/Test-Project/move_meal_dish',
    {
        direction   => 'under',
        source_path => {
            date      => '2000-01-01',
            meal_id   => 1,
            dish_id   => 1,
            item_type => 'dish',
            type      => 'elem',
        },
        target_path => {
            date      => '2000-01-02',
            meal_id   => 2,
            dish_id   => 2,
            item_type => 'dish',
            type      => 'elem',
        },
    }
);
$t->status_is(200);
$t->json_is(
    {
        id                 => 1,
        meal_id            => 2,
        from_recipe_id     => undef,
        prepare_at_meal_id => undef,
        position           => 2,
        date               => '2000-01-02',
        servings           => 4,
        name               => L(),
        comment            => L(),
        description        => L(),
        preparation        => '',
        update_url         => 'https://localhost/project/1/Test-Project/dish/1/update/ajax',
        delete_url         => 'https://localhost/project/1/Test-Project/dish/1/delete/ajax',
    }
);

done_testing;    # TODO remove
