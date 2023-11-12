package Coocook::Model::PurchaseList;

# ABSTRACT: business logic for plain data structure of purchase list

use Coocook::Base;
use Moose;

use Scalar::Util 'weaken';

has list => (
    is       => 'ro',
    isa      => 'Coocook::Schema::Result::PurchaseList',
    required => 1,
);

has [qw( articles dishes shop_sections units )] => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

sub BUILD ( $self, $args ) {
    my $list    = $self->list;
    my $project = $list->project;

    # articles
    my %articles = map { $_->{id} => $_ } $list->articles->hri->all;

    # units: need to select all of project's units because of convertibility
    my %units = map { $_->{id} => $_ } $project->units->hri->all;

    # items
    my %items = map { $_->{id} => $_ } $list->items->hri->all;
    my %items_per_section;

    for my $item ( values %items ) {
        $item->{article}     = $articles{ $item->{article_id} };
        $item->{unit}        = $units{ $item->{unit_id} };
        $item->{total}       = $item->{value} + $item->{offset};
        $item->{ingredients} = [];

        push @{ $items_per_section{ $item->{article}{shop_section_id} || '' } }, $item;
    }

    my @dishes;    # TODO maybe remove block scope

    {              # add ingredients to each item
        my %ingredients_by_dish;

        my $ingredients = $list->items->search_related('ingredients')->hri;

        while ( my $ingredient = $ingredients->next ) {
            $ingredient->{article} = $articles{ $ingredient->{article_id} };
            $ingredient->{unit}    = $units{ $ingredient->{unit_id} };

            push @$_, $ingredient
              for (
                $items{ $ingredient->{item_id} }{ingredients},     # add $ingredient{} to %items
                $ingredients_by_dish{ $ingredient->{dish_id} },    # collect $ingredient{} for dish
              );
        }

        @dishes =
          $list->items->search_related('ingredients')->search_related( 'dish', undef, { distinct => 1 } )
          ->hri->all;

        my %meals = map { $_->{id} => $_ }
          $project->meals->hri->all;    # fetch all meals is probably more efficient than complex query

        for my $meal ( values %meals ) {
            $meal->{date} = $project->parse_date( $meal->{date} );
        }

        for my $dish (@dishes) {
            $dish->{meal} = $meals{ $dish->{meal_id} } || die;

            for my $ingredient ( $ingredients_by_dish{ $dish->{id} }->@* ) {
                $ingredient->{dish} = $dish;
            }
        }
    }

    # sort ingredients per item
    for my $item ( values %items ) {
        my $ingredients = $item->{ingredients};

        @$ingredients = sort {
            if ( $a->{dish_id} == $b->{dish_id} ) {    # items of same dish
                $b->{prepare} <=> $a->{prepare}            # 1. prepared first
                  or $a->{position} <=> $b->{position};    # 2. position inside list
            }
            elsif ( $a->{dish}{meal_id} == $b->{dish}{meal_id} ) {    # items of same meal
                $a->{dish}{position} <=> $b->{dish}{position};
            }
            else {                                                    # unrelated items
                $a->{dish}{meal}{date} <=> $b->{dish}{meal}{date}
                  or $a->{dish}{meal}{position} <=> $b->{dish}{meal}{position};
            }
        } @$ingredients;
    }

    {    # add convertible_into units to each item
        my %conversions;
        {
            my $conversions = $project->unit_conversions->hri;

            # possible performance gains:
            # - use arrayref inflator
            # - set to undef instead of 1 and check with exists()

            while ( my $conversion = $conversions->next ) {
                $conversions{ $conversion->{unit1_id} }{ $conversion->{unit2_id} } = 1;
                $conversions{ $conversion->{unit2_id} }{ $conversion->{unit1_id} } = 1;
            }
        }

        my %units_per_article;    # all units linked to article (may be in use or not)

        {
            my $articles_units = $list->articles->search_related(
                'articles_units',
                undef,
                {
                    distinct => 1,        # otherwise sometimes returns (article_id, unit_id) twice
                    join     => 'unit',
                }
            )->hri;

            while ( my $article_unit = $articles_units->next ) {
                push $units_per_article{ $article_unit->{article_id} }->@*, $article_unit->{unit_id};
            }
        }

        my %convertible_units;    # possible target units by article, source unit

        while ( my ( $article_id => $unit_ids ) = each %units_per_article ) {
            for my $source_unit_id (@$unit_ids) {
                $convertible_units{$article_id}{$source_unit_id} = [
                    map  { $units{$_} || die "invalid unit ID" }
                    grep { $conversions{$source_unit_id}{$_} } @$unit_ids
                ];
            }
        }

        for my $item ( values %items ) {
            $item->{convertible_into} = $convertible_units{ $item->{article}{id} }{ $item->{unit}{id} };
        }
    }

    # shop sections
    my @sections =
      $list->articles->search_related( shop_section => undef, { distinct => 1 } )->hri->all;

    for my $section (@sections) {
        $section->{items} = $items_per_section{ $section->{id} };
    }

    # sort sections
    @sections = sort { $a->{name} cmp $b->{name} } @sections;

    # items with no shop section
    if ( my $items = $items_per_section{''} ) {
        push @sections, { items => $items };
    }

    # sort products alphabetically
    for my $section (@sections) {
        my $items = $section->{items};

        # https://en.wikipedia.org/wiki/Schwartzian_transform
        @$items = sort {    # sort by
            $a->{article}{name} cmp $b->{article}{name}    # 1. article name
              or $a->{unit}{id} <=> $b->{unit}{id}         # 2. unit ID
        } @$items;
    }

    $self->articles( [ values %articles ] );
    $self->dishes( \@dishes );
    $self->units( [ values %units ] );
    $self->shop_sections( \@sections );
}

__PACKAGE__->meta->make_immutable;

1;
