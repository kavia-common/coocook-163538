package Coocook::Model::Plan;

# ABSTRACT: business logic for plain data structures of project/day plans

use Coocook::Base qw(Moose);

use DateTime;
use Scalar::Util 'weaken';
use Carp;

__PACKAGE__->meta->make_immutable;

sub day ( $self, $project, $dt ) {
    my %meals;
    my @meals;

    {
        my $meals = $project->meals->search(
            {
                date => $dt->ymd,
            },
            {
                columns  => [ 'id', 'name', 'comment' ],
                order_by => 'position',
            }
        );

        while ( my $meal = $meals->next ) {
            push @meals,
              $meals{ $meal->id } = {
                name            => $meal->name,
                comment         => $meal->comment,
                dishes          => [],
                prepared_dishes => [],
              };
        }
    }

    my %dishes;
    my $schema = $project->result_source->schema;

    {
        my $dishes = $schema->resultset('Dish');

        $dishes = $dishes->search(
            [    # OR
                meal_id            => { -in => [ keys %meals ] },
                prepare_at_meal_id => { -in => [ keys %meals ] },
            ],
            {
                prefetch => 'prepare_at_meal',
                order_by => $dishes->me('position'),
            }
        );

        while ( my $dish = $dishes->next ) {
            my %dish = (
                id                       => $dish->id,
                name                     => $dish->name,
                comment                  => $dish->comment,
                servings                 => $dish->servings,
                preparation              => $dish->preparation,
                description              => $dish->description,
                has_prepared_ingredients => 0,
                ingredients              => [],
            );

            $dishes{ $dish->id } = \%dish;

            if ( exists $meals{ $dish->meal_id } ) {    # is a dish on this day
                if ( my $meal = $dish->prepare_at_meal ) {
                    $dish{prepare_at_meal} = {
                        date => $dish->prepare_at_meal->date,
                        name => $dish->prepare_at_meal->name,
                    };
                }

                push $meals{ $dish->meal_id }{dishes}->@*, \%dish;
            }

            if ( my $prepare_at_meal = $dish->prepare_at_meal_id ) {
                if ( exists $meals{$prepare_at_meal} ) {    # dish is prepared on this day
                    $dish{meal} = {
                        id   => $dish->meal->id,
                        name => $dish->meal->name,
                        date => $dish->meal->date,
                    };

                    push $meals{ $dish->prepare_at_meal->id }{prepared_dishes}->@*, \%dish;
                }
            }
        }
    }

    {
        my $ingredients = $schema->resultset('DishIngredient');

        $ingredients = $ingredients->search(
            {
                dish_id => { -in => [ keys %dishes ] },
            },
            {
                prefetch => [ 'article', 'unit' ],
                order_by => [
                    $ingredients->me('prepare'),    #perltidy
                    $ingredients->me('position'),
                ],
            }
        );

        while ( my $ingredient = $ingredients->next ) {
            push $dishes{ $ingredient->dish_id }{ingredients}->@*,
              {
                prepare => $ingredient->format_bool( $ingredient->prepare ),
                value   => $ingredient->value,
                unit    => {
                    short_name => $ingredient->unit->short_name,
                    long_name  => $ingredient->unit->long_name,
                },
                article => {
                    name    => $ingredient->article->name,
                    comment => $ingredient->article->comment,
                },
                comment => $ingredient->comment,
              };

            $ingredient->prepare
              and $dishes{ $ingredient->dish_id }{has_prepared_ingredients} = 1;
        }
    }

    return \@meals;
}

sub project ( $self, $project ) {
    my %days;
    my %meals;

    my $meals = $project->meals;
    $meals = $meals->search( undef, { order_by => $meals->me('position') } );

    while ( my $meal = $meals->next ) {
        my $day = $days{ $meal->date } ||= {
            date  => $meal->date,
            meals => [],
        };

        push $day->{meals}->@*,
          $meals{ $meal->id } = $meal->as_hashref(
            date            => $day->{date},
            deletable       => !!$meal->deletable,
            dishes          => [],
            prepared_dishes => [],
          );
    }

    my $dishes = $meals->search_related('dishes')->hri;
    $dishes = $dishes->search( undef, { order_by => $dishes->me('position') } );

    for my $dish ( $dishes->all ) {
        $dish->{meal} = $meals{ $dish->{meal_id} };

        weaken $dish->{meal};

        push $dish->{meal}{dishes}->@*, $dish;

        if ( my $prepare_meal_id = $dish->{prepare_at_meal_id} ) {
            push $meals{$prepare_meal_id}{prepared_dishes}->@*, $dish;
        }
    }
    return [ @days{ sort keys %days } ];
}

sub project_for_meals_dishes_editor ( $self, $project ) {
    my %days;

    my $meals = $project->meals;

    while ( my $meal = $meals->next ) {
        my $day = $days{ $meal->date->ymd } ||= {};

        $day->{ $meal->id } = $meal->for_meals_dishes_editor;
    }

    return \%days;
}

sub resolve_meal_dish_path ( $self, $project, $path ) {
    if ( $path->{item_type} eq 'dish' ) {
        return $project->dishes->find( $path->{dish_id} );
    }
    elsif ( $path->{item_type} eq 'meal' ) {
        return $project->meals->find( $path->{meal_id} );
    }
    die;
}

1;
