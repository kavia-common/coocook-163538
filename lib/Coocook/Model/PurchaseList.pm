package Coocook::Model::PurchaseList;

# ABSTRACT: business logic for plain data structure of purchase list

use Coocook::Base qw(Moose);

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
        my $ucg = $project->unit_conversion_graph;

        my %suggested_units_per_article;

        {
            my $articles_units = $list->articles->search_related(
                'articles_units',
                undef,
                {
                    columns => [ 'article_id', 'unit_id' ],
                }
            )->hri;

            while ( my $row = $articles_units->next ) {
                $suggested_units_per_article{ $row->{article_id} }{ $row->{unit_id} } = 1;
            }
        }

        my %items_per_unit;
        for my $item ( values %items ) {
            push $items_per_unit{ $item->{unit_id} }->@*, $item;
        }

        while ( my ( $source_unit_id => $items ) = each %items_per_unit ) {
            my @target_unit_ids = $ucg->unit_convertible_into($source_unit_id);

            for my $item (@$items) {
                my @convertible_into;

                for my $target_unit_id (@target_unit_ids) {
                    my $factor = $ucg->factor_between_units( $source_unit_id => $target_unit_id );

                    my %convertible_into = (
                        $units{$target_unit_id}->%*,
                        value     => $item->{value} * $factor,
                        offset    => $item->{offset} * $factor,
                        suggested => !!$suggested_units_per_article{ $item->{article_id} }{$target_unit_id},
                    );

                    $convertible_into{total} = $convertible_into{value} + $convertible_into{offset};
                    push @convertible_into, \%convertible_into;
                }

                $item->{convertible_into} = _sort_convertible_into( \@convertible_into );
            }
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

sub _sort_convertible_into ($convertible_into) {
    my @convertible_into = sort {
        $a->{suggested}    # TODO more readable syntax or native operator?
          ? ( $b->{suggested} ? 0 : -1 )
          : ( $b->{suggested} ? 1 : 0 )
          or length( $a->{total} ) <=> length( $b->{total} )
          or $b->{total} <=> $a->{total}
    } @$convertible_into;

    return \@convertible_into;
}

1;
