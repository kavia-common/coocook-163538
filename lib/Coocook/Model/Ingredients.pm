package Coocook::Model::Ingredients;

# ABSTRACT: business logic for plain data structures from Dish- or RecipeIngredients

use Coocook::Base;
use Moose;

use Moose::Util::TypeConstraints;

class_type 'Coocook::Schema::ResultSet::DishIngredient';
class_type 'Coocook::Schema::ResultSet::RecipeIngredient';

has all_articles => (
    is  => 'rw',
    isa => 'ArrayRef[Coocook::Schema::Result::Article]',
);

has all_units => (
    is  => 'rw',
    isa => 'ArrayRef[Coocook::Schema::Result::Unit]',
);

has factor => (
    is      => 'rw',
    isa     => 'Num',
    default => 1,
);

has ingredients => (
    is  => 'ro',
    isa => 'Coocook::Schema::ResultSet::DishIngredient | Coocook::Schema::ResultSet::RecipeIngredient',
    required => 1,
);

has project => (
    is      => 'ro',
    isa     => 'Coocook::Schema::Result::Project',
    lazy    => 1,
    builder => 'build_project',
);

around BUILDARGS => sub ( $orig, $class, %args ) {
    if ( my $dish = delete $args{dish} ) {
        $args{project}     = $dish->project;
        $args{ingredients} = $dish->ingredients;
    }
    elsif ( my $recipe = delete $args{recipe} ) {
        $args{project}     = $recipe->project;
        $args{ingredients} = $recipe->ingredients;
    }

    return $class->$orig(%args);
};

sub build_project ($self) { $self->ingredients->one_row->project }

sub as_arrayref ($self) {
    my ( $articles => $units ) = $self->project->articles_cached_units;

    my %articles = map { $_->id => $_ } @$articles;
    my %units    = map { $_->id => $_ } @$units;

    my @ingredients;
    {
        my $ingredients = $self->ingredients->sorted;

        while ( my $ingredient = $ingredients->next ) {
            push @ingredients,
              {
                id       => $ingredient->id,
                prepare  => $ingredient->format_bool( $ingredient->prepare ),
                position => $ingredient->position,
                value    => $ingredient->value * $self->factor,
                comment  => $ingredient->comment,
                unit     => $units{ $ingredient->unit_id },
                article  => $articles{ $ingredient->article_id },
              };
        }
    }

    $self->all_articles($articles);
    $self->all_units($units);

    return \@ingredients;
}

sub for_ingredients_editor ($self) {
    my $ingredients = $self->as_arrayref;

    my @ingredients = map {
        my $unit              = $_->{unit};
        my @convertible_units = $_->{article}->units->search(
            {
                id => { '!=' => $unit->id },
            }
        )->all;
        my @units;

        # transform Result::Unit objects into plain hashes
        $unit = { map { $_ => $unit->get_column($_) } qw<id short_name long_name> };
        for (@convertible_units) {
            my $u = $_;

            push @units, { map { $_ => $u->get_column($_) } qw<id short_name long_name> };
        }

        {
            id       => $_->{id},
            prepare  => $_->{prepare},
            position => $_->{position},
            value    => $_->{value},
            comment  => $_->{comment},
            article  =>
              { name => $_->{article}->name, comment => $_->{article}->comment, id => $_->{article}->id },
            current_unit => $unit,
            units        => \@units,
        }
    } @$ingredients;

    return \@ingredients;
}

1;
