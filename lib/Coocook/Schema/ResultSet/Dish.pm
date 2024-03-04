package Coocook::Schema::ResultSet::Dish;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::ResultSet';

__PACKAGE__->meta->make_immutable;

sub from_recipe ( $self, %args ) {
    return $self->txn_do(
        sub {
            my $recipe = $args{recipe};

            my $dish = $self->create(
                {
                    from_recipe_id => $recipe->id,

                    servings => $args{servings},
                    meal_id  => $args{meal_id},
                    comment  => $args{comment},

                    name        => $args{name}        || $recipe->name,
                    description => $args{description} || $recipe->description,
                    preparation => $args{preparation} || $recipe->preparation,
                }
            );

            $dish->set_tags( [ $recipe->tags->all ] );

            # copy ingredients
            for my $recipe_ingredient ( $recipe->ingredients->all ) {
                my $dish_ingredient = $dish->create_related(
                    ingredients => {
                        value => $recipe_ingredient->value * $args{servings} / $recipe->servings,
                        map { $_ => $recipe_ingredient->$_ } qw<position prepare article unit comment>
                    }
                );

                if ( my $list = $recipe->project->default_purchase_list ) {
                    $dish_ingredient->assign_to_purchase_list($list);
                }
            }

            return $dish;
        }
    );
}

sub sum_servings ($self) { $self->get_column('servings')->sum // 0 }

sub in_past_or_today ($self) {
    return $self->search(
        {
            'meal.date' => { '<=' => $self->format_date_today },
        },
        {
            join => 'meal',
        }
    );
}

sub in_future ($self) {
    return $self->search(
        {
            'meal.date' => { '>' => $self->format_date_today },
        },
        {
            join => 'meal',
        }
    );
}

sub update_items_and_delete ($self) {
    $self->txn_do(
        sub {
            $self->assert_no_sth;

            while ( my $dish = $self->next ) {
                $dish->update_items_and_delete;
            }
        }
    );
}

1;
