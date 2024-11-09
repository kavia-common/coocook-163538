package Coocook::Schema::Component::Result::DishOrRecipe;

use Coocook::Base;

use Carp;

sub dish_or_recipe ($self) {
    return
        $self->is_dish   ? 'dish'
      : $self->is_recipe ? 'recipe'
      :                    die "code broken";
}

sub is_dish   ($self) { $self->isa('Coocook::Schema::Result::Dish') }
sub is_recipe ($self) { $self->isa('Coocook::Schema::Result::Recipe') }

sub add_ingredient ( $self, %args ) {
    exists $args{article_id} or exists $args{article_name} or croak "article missing";
    exists $args{unit_id}    or exists $args{unit_name}    or croak "unit missing";
    exists $args{$_}         or croak "$_ missing" for qw( comment prepare value );

    $self->txn_do(
        sub {
            $self->svp_begin();

            my $project = $self->project;

            my ( $article, $unit );

            if ( defined $args{article_id} ) {
                $article = $project->articles->find( $args{article_id} );
            }
            elsif ( defined $args{article_name} ) {
                $article = $project->articles->find_or_new( { name => $args{article_name} } );
            }

            if ( defined $args{unit_id} ) {
                $unit = $project->units->find( $args{unit_id} );
            }
            elsif ( defined( my $name = $args{unit_name} ) ) {
                $unit = $project->units->one_row(
                    [    # OR
                        { short_name => $name },
                        { long_name  => $name },
                    ]
                ) || $project->units->create( { short_name => $name, long_name => $name } );
            }

            if ( !$article or !$unit ) {
                $self->svp_rollback();
                return;
            }

            if ( not $article->in_storage ) {
                $article->set_columns( { comment => '' } );
                $article->create_related( articles_units => { unit => $unit } );
            }

            my $ingredient = $self->create_related(
                ingredients => {
                    article_id => $article->id,
                    unit_id    => $unit->id,
                    %args{qw( comment prepare value )},
                }
            );

            if ( $self->is_dish ) {
                if ( my $list_id = $project->default_purchase_list_id ) {
                    $ingredient->assign_to_purchase_list($list_id);
                }
            }

            $self->svp_release();

            return $ingredient;
        }
    );
}

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
