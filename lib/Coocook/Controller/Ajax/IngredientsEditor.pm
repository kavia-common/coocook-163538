package Coocook::Controller::Ajax::IngredientsEditor;

use Coocook::Base qw(Moose);

use JSON::MaybeXS;

BEGIN { extends 'Coocook::Controller' }

=head1 NAME

Coocook::Controller::Ajax::IngredientsEditor - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub base : Chained('/project/base') PathPart('') CaptureArgs(2) {
    my ( $self, $c, $dish_or_recipe, $dish_or_recipe_id ) = @_;

    return $c->detach('/error/not_found')
      unless ( $dish_or_recipe eq 'dish' or $dish_or_recipe eq 'recipe' );

    my $plural = $dish_or_recipe eq 'dish' ? 'dishes' : 'recipes';
    $c->stash( dish_or_recipe => $c->project->$plural->find($dish_or_recipe_id)
          || $c->detach('/error/not_found') );
}

sub get_all_ingredients : GET HEAD Chained('base') PathPart('ingredients')
  RequiresCapability('view_project') {
    my ( $self, $c ) = @_;

    my $ingredients = $c->model('Ingredients')->new(
        project     => $c->project,
        ingredients => $c->stash->{dish_or_recipe}->ingredients,
    );

    $c->stash->{json_data} = $ingredients->for_ingredients_editor
      or die 'Error when converting ingredients to IngredientsEditor format.';
}

sub update_ingredient : POST Chained('base') PathPart('ingredients/update')
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;
    my $json       = $c->req->body_data;
    my $ingredient = $json->{ingredient};

    my $dish_or_recipe = $c->stash->{dish_or_recipe};

    my $ingrDB = $dish_or_recipe->search_related('ingredients')->find( $ingredient->{id} );
    $ingrDB->update(
        {
            value   => $ingredient->{value},
            unit_id => $ingredient->{current_unit}{id},
            comment => $ingredient->{comment},
        }
    );

    $c->stash->{json_data} = { id => $ingrDB->id };
}

sub prepend_ingredient : POST Chained('base') PathPart('ingredients/prepend')
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    $c->forward( '_xpend_ingredient', [1] );
}

sub append_ingredient : POST Chained('base') PathPart('ingredients/append')
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    $c->forward( '_xpend_ingredient', [undef] );
}

sub _xpend_ingredient : Private {
    my ( $self, $c, $position ) = @_;

    my $dish_or_recipe = $c->stash->{dish_or_recipe};

    my $json          = $c->req->body_data;
    my $ingredient_id = $json->{ingredientId};
    my $prepare       = $json->{prepare};

    my $ingredient = $dish_or_recipe->search_related('ingredients')->find($ingredient_id)
      or $c->redirect('/error/bad_request');

    my %id_hash =
        $ingredient->is_recipe_ingredient ? ( recipe_id => $ingredient->recipe_id )
      : $ingredient->is_dish_ingredient   ? ( dish_id => $ingredient->dish_id )
      :                                     die "code broken";

    $ingredient->move_to_group( { %id_hash, prepare => $prepare }, $position );

    $c->stash->{json_data} = { success => 1 };
}

sub move_ingredient : POST Chained('base') PathPart('ingredients/move')
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $dish_or_recipe = $c->stash->{dish_or_recipe};

    my $json      = $c->req->body_data;
    my $source_id = $json->{sourceId};
    my $target_id = $json->{targetId};
    my $direction = $json->{direction};

    my $source_db = $dish_or_recipe->search_related('ingredients')->find($source_id);
    my $target_db = $dish_or_recipe->search_related('ingredients')->find($target_id);

    my $new_position =
        $direction eq 'upwards'   ? $target_db->position
      : $direction eq 'downwards' ? $target_db->position + 1
      :   $c->detach( '/error/bad_request', ["Invalid move direction `$direction`"] );

    my %id_hash =
        $target_db->is_dish_ingredient   ? ( dish_id => $target_db->dish_id )
      : $target_db->is_recipe_ingredient ? ( recipe_id => $target_db->recipe_id )
      :                                    die "code broken";

    $source_db->move_to_group( { %id_hash, prepare => $target_db->prepare }, $new_position );
    $c->stash->{json_data} = { success => 1 };
}

sub delete_ingredient : POST Chained('base') PathPart('ingredients/delete')
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;
    my $json = $c->req->body_data;

    my $dish_or_recipe = $c->stash->{dish_or_recipe};

    my $ingrDB = $dish_or_recipe->search_related('ingredients')->find( $json->{id} );
    $ingrDB->delete();

    $c->stash->{json_data} = { id => $ingrDB->id };
}

sub all_articles : GET HEAD Chained('base') PathPart('articles') RequiresCapability('view_project')
{
    my ( $self, $c ) = @_;
    my $project = $c->stash->{project};
    $c->stash->{json_data} =
      [ $project->articles->search( undef, { columns => [ 'id', 'name', 'comment' ] } )->hri->all ];
}

sub all_units : GET HEAD Chained('base') PathPart('units') RequiresCapability('view_project') {
    my ( $self, $c ) = @_;
    my $project = $c->stash->{project};
    $c->stash->{json_data} = [
        map {
            my $u = $_;
            $u->{articles} = [ map { $_->{article_id} } $u->{articles_units}->@* ];
            delete $u->{articles_units};
            $u
        } $project->units->search(
            undef,
            {
                columns  => [ 'id', 'short_name', 'long_name' ],
                prefetch => 'articles_units',
            }
        )->hri->all
    ];
}

sub add_ingredient : POST Chained('base') PathPart('ingredients/create')
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $dish_or_recipe = $c->stash->{dish_or_recipe};
    my $project        = $c->stash->{project};
    my $properties     = $c->req->body_data->{ingredient};

    my $txn_scope_guard = $c->model('DB')->txn_scope_guard;

    my ( $article, $unit );

    if ( defined( my $id = $properties->{article}{id} ) ) {
        $article = $project->articles->find($id);
    }
    elsif ( defined( my $name = $properties->{article}{name} ) ) {
        $article = $project->articles->find_or_new( { name => $name } );
    }

    if ( defined( my $id = $properties->{unit}{id} ) ) {
        $unit = $project->units->find($id);
    }
    elsif ( defined( my $name = $properties->{unit}{name} ) ) {
        $unit = $project->units->search(
            [    # OR
                { short_name => $name },
                { long_name  => $name },
            ]
          )->one_row
          || $project->units->create( { short_name => $name, long_name => $name } );
    }

    ( $article and $unit )
      or $c->detach('/error/bad_request');

    if ( not $article->in_storage ) {
        $article->set_columns( { comment => '' } );
        $article->create_related( articles_units => { unit => $unit } );
    }

    $dish_or_recipe->create_related(
        ingredients => {
            article_id => $article->id,
            unit_id    => $unit->id,
            value      => $properties->{amount},    # TODO https://gitlab.com/coocook/web-components/-/issues/54
            $properties->%{qw( comment prepare )},
        }
    );

    $txn_scope_guard->commit;

    $c->stash->{json_data} = { success => 1 };
}

1;
