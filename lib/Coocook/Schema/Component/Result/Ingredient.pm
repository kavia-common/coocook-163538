package Coocook::Schema::Component::Result::Ingredient;

use Coocook::Base;

sub dish_or_recipe ($self) {
    return
        $self->is_dish_ingredient   ? 'dish'
      : $self->is_recipe_ingredient ? 'recipe'
      :                               die "code broken";
}

sub is_dish_ingredient   ($self) { $self->isa('Coocook::Schema::Result::DishIngredient') }
sub is_recipe_ingredient ($self) { $self->isa('Coocook::Schema::Result::RecipeIngredient') }

1;
