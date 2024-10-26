use Test2::V0;

use DateTime;

use lib 't/lib';
use Test::Coocook;

plan(17);

my $t = Test::Coocook->new();

$t->get_ok('/');
$t->login_ok( 'john_doe', 'P@ssw0rd' );

ok $t->post('/project/1/Test-Project/move_meal_dish'), "empty formdata request";
$t->status_is(400);

ok $t->post_json( '/project/1/Test-Project/move_meal_dish', {} ), "empty JSON request";
$t->status_is(400);

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
        update_url         => 'https://localhost/project/1/Test-Project/dish/1/update',
        delete_url         => 'https://localhost/project/1/Test-Project/dish/1/delete',
    }
);

$t->post_ok(
    '/project/1/Test-Project/meals/create',
    {
        date    => '2000-01-01',
        name    => 'meal from test',
        comment => __FILE__,
    }
);

$t->json_is(
    {
        meal => hash {
            field id   => 10;
            field name => 'meal from test';
            etc();
        },
    }
);

subtest "update mals" => sub {
    my $meal1 = $t->schema->resultset('Meal')->find(1);
    my $meal2 = $t->schema->resultset('Meal')->find(2);

    ok $t->post_json( '/project/1/Test-Project/meals/10/update', {} ), "POST /update with empty JSON";
    $t->status_is(400);

    ok $t->post_json( '/project/1/Test-Project/meals/10/update', { date => 'foo' } ),
      "POST /update with invalid date";
    $t->status_is(400);
    $t->json_is( { error => { message => match qr/invalid date string/ } } );

    ok $t->post_json(
        '/project/1/Test-Project/meals/10/update',
        { date => $meal1->date->ymd, name => $meal1->name }
      ),
      "POST /update with existing date and name";
    $t->status_is(400);
    $t->json_is( { error => { message => match qr/same name on same date/ } } );

    ok $t->post_json( '/project/1/Test-Project/meals/1/update',
        { date => $meal1->date->ymd, name => $meal1->name, comment => __FILE__ } ),
      "POST /update with unchanged date and name";
    $t->status_is(200);
    is $meal1->discard_changes->comment => __FILE__, "comment was updated";

    my %update_request = (
        date    => $meal2->date->ymd,
        name    => 'extra meal',
        comment => __FILE__,
    );

    for my $missing_key ( keys %update_request ) {
        ok $t->post_json(
            '/project/1/Test-Project/meals/1/update',
            { %update_request, $missing_key => undef }
          ),
          "POST /update with missing key '$missing_key'";
        $t->status_is(400);
        if ( $t->res->content_length > 0 ) {
            $t->json_is( { error => { message => T() } } );
        }
    }

    ok $t->post_json( '/project/1/Test-Project/meals/1/update', \%update_request ),
      "POST /update with unchanged date and name";
    $t->status_is(200);
    $t->json_is(
        {
            id              => 1,
            name            => 'extra meal',
            project_id      => 1,
            position        => 1,
            comment         => __FILE__,
            date            => '2000-01-02',
            deletable       => T(),
            prepared_dishes => {},
            dishes          => {},
        }
    );

    is $meal1->discard_changes => object {
        call date => object { call ymd => '2000-01-02' };
        call name => 'extra meal';
    },
      "was updated in database";

    my @update_conflict = (
        '/project/1/Test-Project/meals/1/update',
        {
            name    => $meal2->name,
            date    => $meal2->date->ymd,
            comment => __FILE__ . ":" . __LINE__,
        }
    );
    $t->post_json(@update_conflict);
    $t->status == 400 or die "test broken";

    $update_conflict[1]{date} = '2000-01-01';    # set duplicate name but move to different date
    $t->post_json(@update_conflict);
    $t->status_is(200);

    $meal1->discard_changes();
    is $meal1->name      => $meal2->name;
    is $meal1->date->ymd => '2000-01-01';
    is $meal1->comment   => __FILE__ . ":" . ( __LINE__ - 13 );
};

ok $t->post('/project/1/Test-Project/meals/2/delete'), "POST /delete on meal with dishes";
$t->status_is(400);
$t->json_is( { error => { message => match qr/cannot be deleted/ } } );

$t->post_ok('/project/1/Test-Project/meals/10/delete');
ok !$t->schema->resultset('Meal')->find(10), "meal not found in database anymore";
