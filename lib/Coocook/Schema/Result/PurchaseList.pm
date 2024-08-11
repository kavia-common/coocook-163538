package Coocook::Schema::Result::PurchaseList;

use Coocook::Base qw(Moose);

use Carp;

extends 'Coocook::Schema::Result';

__PACKAGE__->table('purchase_lists');

__PACKAGE__->add_columns(
    id         => { data_type => 'integer', is_auto_increment => 1 },
    project_id => { data_type => 'integer' },
    name       => { data_type => 'text' },
    date       => { data_type => 'date' },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->add_unique_constraints( [qw<project_id name>] );

__PACKAGE__->belongs_to( project => 'Coocook::Schema::Result::Project', 'project_id' );

__PACKAGE__->has_many(
    items => 'Coocook::Schema::Result::Item',
    'purchase_list_id'
);

__PACKAGE__->many_to_many( ingredients => items => 'ingredients' );
__PACKAGE__->many_to_many( articles    => items => 'article' );
__PACKAGE__->many_to_many( units       => items => 'unit' );

__PACKAGE__->has_many(
    other_purchase_lists => __PACKAGE__,
    sub ($args) {
        return {
            "$args->{foreign_alias}.id"         => { '!='   => { -ident => "$args->{self_alias}.id" } },
            "$args->{foreign_alias}.project_id" => { -ident => "$args->{self_alias}.project_id" },
        };
    }
);

around delete => sub ( $orig, $self, $ucg = undef ) {
    $self->txn_do(
        sub {
            my $project      = $self->project;
            my $default_list = $project->default_purchase_list
              || die "default purchase list required because project has a purchase list (self)";

            if ( $default_list->id == $self->id ) {
                if ( $self->other_purchase_lists->results_exist ) {
                    croak "Purchase list is default list";
                }
                else {
                    $project->update( { default_purchase_list_id => undef } );
                }
            }

            $self->move_items_ingredients(
                target_purchase_list => $default_list,
                ingredients          => [],
                items                => [ $self->items->all ],
                ucg                  => $ucg || $project->unit_conversion_graph,
            );

            return $self->$orig();
        }
    );
};

around insert => sub ( $orig, $self ) {
    $self->txn_do(
        sub {
            my $return = $self->$orig();

            my $project = $self->project;

            if ( not defined $project->default_purchase_list_id ) {
                $project->update( { default_purchase_list_id => $self->id } );

                my $ingredients = $project->dishes->search_related('ingredients');

                while ( my $ingredient = $ingredients->next ) {
                    $ingredient->assign_to_purchase_list($self);
                }
            }

            return $return;
        }
    );
};

__PACKAGE__->meta->make_immutable;

sub is_default ($self) {
    if ( $self->has_column_loaded('is_default') ) {    # extra column from RS->with_is_default()
        return $self->get_column('is_default');
    }
    else {
        return (
            ( $self->project->default_purchase_list_id // die 'project has no default_purchase_list_id' ) ==
              $self->id );
    }
}

sub make_default ($self) {
    $self->project->update( { default_purchase_list_id => $self->id } );

    return $self;
}

sub move_items_ingredients ( $self, %args ) {
    $args{$_} || croak "Missing named parameter '$_'"
      for qw( target_purchase_list items ingredients ucg );

    $self->txn_do(
        sub {
            my %items_done;
            my %ingredients_per_item;

            for my $item ( $args{items}->@* ) {
                if ( $args{target_purchase_list}
                    ->items->results_exist( { article_id => $item->article_id, unit_id => $item->unit_id } ) )
                {    # conflicts UNIQUE constraint!
                    $ingredients_per_item{ $item->id } = [ $item->ingredients->all ];
                    $item->delete();
                }
                else {
                    $item->update( { purchase_list_id => $args{target_purchase_list}->id } );
                }

                $items_done{ $item->id } = 1;
            }

            # group selected ingredients by item_id
            for my $ingredient ( $args{ingredients}->@* ) {
                next if $items_done{ $ingredient->item_id };    # whole item selected

                push $ingredients_per_item{ $ingredient->item_id }->@*, $ingredient;
            }

            my %items = map { $_->id => $_ } $self->items->all;

            while ( my ( $item_id => $ingredients ) = each %ingredients_per_item ) {
                $items_done{$item_id}
                  or $items{$item_id}->remove_ingredients( $args{ucg}, @$ingredients );

                for my $ingredient (@$ingredients) {
                    $ingredient->assign_to_purchase_list( $args{target_purchase_list} );
                }
            }
        }
    );
}

1;
