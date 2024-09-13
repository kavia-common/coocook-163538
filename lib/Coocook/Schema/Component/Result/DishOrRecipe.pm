package Coocook::Schema::Component::Result::DishOrRecipe;

use Coocook::Base;

sub dish_or_recipe ($self) {
    return
        $self->is_dish   ? 'dish'
      : $self->is_recipe ? 'recipe'
      :                    die "code broken";
}

sub is_dish   ($self) { $self->isa('Coocook::Schema::Result::Dish') }
sub is_recipe ($self) { $self->isa('Coocook::Schema::Result::Recipe') }

sub duplicate ( $self, $args ) {
    $args->{name} // die "no name defined in \$args";

    return $self->copy($args);
}

sub recalculate ( $self, $servings2 ) {
    my $servings1 = $self->servings;

    $self->txn_do(
        sub {
            for my $ingredient ( $self->ingredients->all ) {
                my $new_value = $ingredient->value / $servings1 * $servings2;

                if ( $self->is_dish ) {
                    $ingredient->set_value_update_item($new_value);
                }
                else {
                    $ingredient->update( { value => $new_value } );
                }
            }

            $self->update( { servings => $servings2 } );
        }
    );
}

sub url_name ($self) { Coocook::Util::url_name( $self->name ) }

1;
