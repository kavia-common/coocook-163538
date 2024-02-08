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

sub project_base : Chained('/project/base') PathPart('') CaptureArgs(2)
  RequiresCapability('view_project') {
    my ( $self, $c, $dish_or_recipe, $dish_or_recipe_id ) = @_;

    return $c->detach('/error/not_found')
      unless ( $dish_or_recipe eq 'dish' or $dish_or_recipe eq 'recipe' );

    my $plural = $dish_or_recipe eq 'dish' ? 'dishes' : 'recipes';
    $c->stash( dish_or_recipe => $c->project->$plural->find($dish_or_recipe_id)
          || $c->detach('/error/not_found') );
}

sub get_all_ingredients : GET PathPart('ingredients') HEAD Chained('project_base')
  RequiresCapability('view_project') {
    my ( $self, $c ) = @_;

    my $ingredients = $c->model('Ingredients')->new(
        project     => $c->project,
        ingredients => $c->stash->{dish_or_recipe}->ingredients,
    );

    $c->stash->{json_data} = $ingredients->for_ingredients_editor
      or die 'Error when converting ingredients to IngredientsEditor format.';
}

sub update_ingredient : POST PathPart('ingredients/update') Chained('project_base')
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;
    my $json       = $c->req->body_data;
    my $ingredient = $json->{ingredient};

    my $dish_or_recipe = $c->stash->{dish_or_recipe};

    my $ingrDB = $dish_or_recipe->search_related('ingredients')->find( $ingredient->{id} );
    $ingrDB->update(
        {
            value   => $ingredient->{value},
            unit_id => $ingredient->{current_unit}->{id},
            comment => $ingredient->{comment},
        }
    );

    $c->stash->{json_data} = { id => $ingrDB->id };
}

sub prepend_ingredient : POST PathPart('ingredients/prepend') Chained('project_base')
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $dish_or_recipe = $c->stash->{dish_or_recipe};

    my $json          = $c->req->body_data;
    my $ingredient_id = $json->{ingredientId};
    my $prepare       = $json->{prepare};

    my $ingredient = $dish_or_recipe->search_related('ingredients')->find($ingredient_id);
    my %id_hash;
    if ( $ingredient->can('recipe_id') ) {
        $id_hash{recipe_id} = $ingredient->recipe_id;
    }
    elsif ( $ingredient->can('dish_id') ) {
        $id_hash{dish_id} = $ingredient->dish_id;
    }
    $ingredient->move_to_group( { %id_hash, prepare => $prepare }, 1 );

    $c->stash->{json_data} = { success => 1 };
}

sub append_ingredient : POST PathPart('ingredients/append') Chained('project_base')
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $dish_or_recipe = $c->stash->{dish_or_recipe};

    my $json          = $c->req->body_data;
    my $ingredient_id = $json->{ingredientId};
    my $prepare       = $json->{prepare};

    my $ingredient = $dish_or_recipe->search_related('ingredients')->find($ingredient_id);
    my %id_hash;
    if ( $ingredient->can('recipe_id') ) {
        $id_hash{recipe_id} = $ingredient->recipe_id;
    }
    elsif ( $ingredient->can('dish_id') ) {
        $id_hash{dish_id} = $ingredient->dish_id;
    }
    $ingredient->move_to_group( { %id_hash, prepare => $prepare }, undef );

    $c->stash->{json_data} = { success => 1 };
}

sub move_ingredient : POST PathPart('ingredients/move') Chained('project_base')
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $dish_or_recipe = $c->stash->{dish_or_recipe};

    my $json      = $c->req->body_data;
    my $source_id = $json->{sourceId};
    my $target_id = $json->{targetId};
    my $direction = $json->{direction};

    my $source_db = $dish_or_recipe->search_related('ingredients')->find($source_id);
    my $target_db = $dish_or_recipe->search_related('ingredients')->find($target_id);

    my $new_position;
    if ( $direction eq 'upwards' ) {
        $new_position = $target_db->position;
    }
    elsif ( $direction eq 'downwards' ) {
        $new_position = $target_db->position + 1;
    }
    else {
        die "Invalid move direction `$direction`";
    }

    my %id_hash;
    if ( $target_db->can('recipe_id') ) {
        $id_hash{recipe_id} = $target_db->recipe_id;
    }
    elsif ( $target_db->can('dish_id') ) {
        $id_hash{dish_id} = $target_db->dish_id;
    }

    $source_db->move_to_group(
        {
            %id_hash, prepare => $target_db->prepare,
        },
        $new_position
    );
    $c->stash->{json_data} = { success => 1 };
}

sub delete_ingredient : POST PathPart('ingredients/delete') Chained('project_base')
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;
    my $json = $c->req->body_data;

    my $dish_or_recipe = $c->stash->{dish_or_recipe};

    my $ingrDB = $dish_or_recipe->search_related('ingredients')->find( $json->{id} );
    $ingrDB->delete();

    $c->stash->{json_data} = { id => $ingrDB->id };
}

sub all_articles : GET HEAD PathPart('articles') Chained('project_base')
  RequiresCapability('view_project') {
    my ( $self, $c ) = @_;
    my $project = $c->stash->{project};
    $c->stash->{json_data} =
      [ $project->articles->search( undef, { columns => [ 'id', 'name', 'comment' ] } )->hri->all ];
}

sub all_units : GET HEAD PathPart('units') Chained('project_base')
  RequiresCapability('view_project') {
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

sub add_ingredient : POST PathPart('ingredients/create') Chained('project_base')
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $dish_or_recipe = $c->stash->{dish_or_recipe};

    my $project = $c->stash->{project};

    my $ingredient = $c->req->body_data->{ingredient};
    my $existing_article;
    if ( defined $ingredient->{article}->{name} ) {
        $existing_article = $project->articles->find( { name => $ingredient->{article}->{name} } );
    }
    elsif ( defined $ingredient->{article}->{id} ) {

        $existing_article = $project->articles->find( { id => $ingredient->{article}->{id} } );
    }
    my $existing_unit;
    if ( defined $ingredient->{unit}->{name} ) {
        $existing_unit = $project->units->search(
            [ { short_name => $ingredient->{unit}->{name} }, { long_name => $ingredient->{unit}->{name} } ] )
          ->one_row;
    }
    elsif ( defined $ingredient->{unit}->{id} ) {

        $existing_unit = $project->units->find( { id => $ingredient->{unit}->{id} } );
    }

    my %new_ingredient = (
        article_id => $existing_article && $existing_article->id,
        unit_id    => $existing_unit    && $existing_unit->id,
        comment    => $ingredient->{comment},
        value      => $ingredient->{amount},
        prepare    => $ingredient->{prepare},
    );

    # 4 general cases
    # unit and article don't exist
    if (    !$existing_article
        and !$existing_unit
        and defined $ingredient->{article}->{name}
        and defined $ingredient->{unit}->{name} )
    {

        # create both and connect them
        $new_ingredient{article_id} = $project->articles->create(
            {
                name    => $ingredient->{article}->{name},
                comment => '',
            },
        )->id;
        my $unit = $project->units->create(
            {
                short_name => $ingredient->{unit}->{name},
                long_name  => $ingredient->{unit}->{name},
            }
        );
        $unit->create_related(
            articles_units => {
                article_id => $new_ingredient{article_id},
            }
        );
        $new_ingredient{unit_id} = $unit->id;
    }
    elsif ( !$existing_article and defined $existing_unit ) {

        # create article and connect unit to it
        $new_ingredient{article_id} = $project->articles->create(
            {
                name    => $ingredient->{article}->{name},
                comment => '',
            }
        )->id;
        $existing_unit->create_related(
            articles_units => {
                article_id => $new_ingredient{article_id},
            }
        );
    }
    elsif ( defined $existing_article and !$existing_unit ) {

        # create unit and connect it to the ingredient, but not the article
        $new_ingredient{unit_id} = $project->units->create(
            {
                short_name => $ingredient->{unit}->{name},
                long_name  => $ingredient->{unit}->{name},
            }
        )->id;
    }

    # last case: both exist and just a ingredient must be created with the ids of the articles
    # => we don't need to anything because $article_id and $unit_id have already the right values

    $dish_or_recipe->create_related( ingredients => \%new_ingredient );

    $c->stash->{json_data} = { success => 1 };
}

1;
