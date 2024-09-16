use Test2::V0;

use DateTime;
use Test::Memory::Cycle;

use lib 't/lib';
use TestDB qw(txn_do_and_rollback);

plan(7);

my $db = TestDB->new();

subtest inventory => sub {
    my $inventory = $db->resultset('Project')->find(1)->inventory();

    is $inventory => {
        articles         => 5,
        dishes           => 3,
        meals            => 3,
        purchase_lists   => 2,
        recipes          => 1,
        shop_sections    => 2,
        tags             => 3,
        tag_groups       => 1,
        units            => 6,
        unassigned_items => 0,
    };
};

subtest articles_cached_units => txn_do_and_rollback $db => sub {
    my $project = $db->resultset('Project')->find(1);

    ok my @result = $project->articles_cached_units, "\$project->articles_cached_units";

    is \@result => array {
        item array { etc() };
        item array { etc() };
    },
      "... returned 2 arrayrefs";

    memory_cycle_ok \@result, "... result is free of memory cycles";

    # delete all entries to make sure everything is cached
    for my $rs (qw< DishIngredient Item ArticleTag RecipeIngredient Article Unit >) {
        ok $db->resultset($rs)->delete, "delete all ${rs}s";
        is $db->resultset($rs)->count => 0, "count($rs) == 0";
    }

    # add new unit to new article to make sure that is cached, too
    my $article = $project->create_related( articles => { name       => "foo", comment   => "" } );
    my $unit    = $project->create_related( units    => { short_name => "b",   long_name => "bar" } );
    $article->add_to_units($unit);

    my ( $articles => $units ) = @result;
    my %articles = map { $_->name => $_ } @$articles;

    is join( ",", map { $_->name } @$articles ) => $_,
      "articles are: $_"
      for 'cheese,flour,love,salt,water';

    todo
      "we need to refactor articles_cached_units() to return a reasonable data structure for units" =>
      sub {
        is join( ",", map { $_->short_name } @$units ) => $_, "units are: $_" for 'g,kg,l';
      };

    my %articles_units = (
        cheese => 'g,kg',
        flour  => 'g,kg',
        love   => '',
        salt   => 'g',
        water  => 'l',
    );

    for my $article ( sort keys %articles_units ) {
        is join( ',', map { $_->short_name } $articles{$article}->units ) => $articles_units{$article},
          "$article has units ($articles_units{$article})";
    }
};

subtest delete => txn_do_and_rollback $db => sub {
    $db->enable_fk_checks();

    my @projects = $db->resultset('Project')->all
      or die "no projects";

    for my $project (@projects) {
        ok $project->delete(), "delete project " . $project->name;
    }

    my %unaffected_sources = map { $_ => 1 } qw<
      BlacklistEmail
      BlacklistUsername
      FAQ
      Organization
      OrganizationUser
      RoleUser
      Terms
      User
    >;

    for my $source ( $db->sources ) {
        $unaffected_sources{$source}
          or is $db->resultset($source)->count => 0,
          "table $source has zero rows";
    }
};

subtest stale => sub {
    my $rs = $db->resultset('Project');

    is [ $rs->stale->get_column('id')->all ] => [ 1, 2, 3 ], "ResultSet::Project->stale for today";

    {
        my $date = DateTime->new( year => 2000, month => 1, day => 2 );    # in the middle of project 1

        is [ $rs->stale($date)->get_column('id')->all ] => [ 2, 3 ],
          "ResultSet::Project->stale for $date";

        subtest "Result::Project->is_stale()" => sub {
            ok $rs->find(1)->is_stale();
            ok $rs->find(2)->is_stale();

            ok !$rs->find(1)->is_stale($date);
            ok $rs->find(2)->is_stale($date);
        };
    }
};

my $project = $db->resultset('Project')->find(1);

subtest find_or_create_tags_from_names => sub {
    my $tags = sub { $project->tags->sorted->get_column('name')->all };

    is [ $tags->() ] => [qw( delicious gluten lactose )];

    isa_ok $project->find_or_create_tags_from_names() => 'Coocook::Schema::ResultSet::Tag';

    is [
        $project->find_or_create_tags_from_names(qw( gluten lactose ))->sorted->get_column('name')->all ]
      => [qw( gluten lactose )];

    is $project->tags->count => 3, "created no tags so far";

    is [
        $project->find_or_create_tags_from_names(qw( gluten foo bar ))->sorted->get_column('name')->all ]
      => [qw( bar foo gluten )];

    is [ $tags->() ] => [qw( bar delicious foo gluten lactose )], "created tags";
};

subtest dishes => sub {
    isa_ok my $dishes = $project->dishes => 'Coocook::Schema::ResultSet::Dish';
    is $dishes->count => 3;
};

subtest items => sub {
    isa_ok my $meals = $project->meals => 'Coocook::Schema::ResultSet::Meal';
    is $meals->count => 3;
};
