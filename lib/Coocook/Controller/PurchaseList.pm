package Coocook::Controller::PurchaseList;

use Coocook::Base qw(Moose);

use DateTime;
use JSON::MaybeXS qw/to_json/;

BEGIN { extends 'Coocook::Controller' }

__PACKAGE__->config( namespace => 'purchase_list' );

=head1 NAME

Coocook::Controller::PurchaseList - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : GET HEAD Chained('/project/base') PathPart('purchase_lists') Args(0)
  RequiresCapability('view_project') {
    my ( $self, $c ) = @_;

    my $project = $c->project;
    my $lists   = $project->purchase_lists;
    my @lists   = $lists->sorted->with_is_default->with_items_count->with_ingredients_count->hri->all;

    for my $list (@lists) {
        $list->{date} = $lists->parse_date( $list->{date} );

        $list->{edit_url}   = $c->project_uri( $self->action_for('edit'),   $list->{id} );
        $list->{update_url} = $c->project_uri( $self->action_for('update'), $list->{id} );
        $list->{make_default_url} =
          !$list->{is_default} ? $c->project_uri( $self->action_for('make_default'), $list->{id} ) : undef;
        $list->{delete_url} =
          ( @lists == 1 or !$list->{is_default} )
          ? $c->project_uri( $self->action_for('delete'), $list->{id} )
          : undef;
    }

    my $default_list = do {
        my @default_lists = grep { $_->{is_default} } @lists;

            @default_lists == 0 ? undef
          : @default_lists == 1 ? $default_lists[0]
          :                       die "multiple lists with 'is_default' flag";
    };

    my $today = DateTime->today;

    $c->stash(
        default_date => $lists->default_date($today),
        default_list => $default_list,
        min_date     => $today,
        lists        => \@lists,
        create_url   => $c->project_uri( $self->action_for('create') ),
    );
}

sub base : Chained('/project/base') PathPart('purchase_list') CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;

    $c->stash( lists => my $lists = $c->project->purchase_lists );
    $c->stash( list  => $lists->find($id) || $c->detach('/error/not_found') );
}

sub edit : GET HEAD Chained('base') PathPart('') Args(0) RequiresCapability('view_project') {
    my ( $self, $c ) = @_;

    my $list = $c->model('PurchaseList')->new( list => $c->stash->{list} );

    $c->stash(
        sections => $list->shop_sections,
        units    => $list->units,
    );

    for my $article ( $list->articles->@* ) {
        $article->{url} = $c->project_uri( '/article/edit', $article->{id} );
    }

    for my $dish ( $list->dishes->@* ) {
        $dish->{url} = $c->project_uri( '/dish/edit', $dish->{id} );
    }

    $c->has_capability('edit_project')
      or return;

    for my $sections ( $c->stash->{sections}->@* ) {
        for my $item ( $sections->{items}->@* ) {
            $item->{update_offset_url} = $c->project_uri( '/item/update_offset', $item->{id} );

            for my $unit ( $item->{convertible_into}->@* ) {
                $unit->{convert_url} = $c->project_uri(
                    '/item/convert',
                    $item->{id},
                    {
                        total => $unit->{total},
                        unit  => $unit->{id},
                    }
                );
            }
        }
    }

    my @lists = $c->stash->{lists}->search( undef, { order_by => [ 'date', 'name' ] } )->hri->all;
    $c->stash(
        lists         => \@lists,
        lists_json    => to_json( \@lists ),
        sections_json => to_json( [ $c->project->shop_sections->hri->all ] )
    );
}

sub assign_articles_to_shop_section : POST Chained('base') Args(0)
  RequiresCapability('view_project') {
    my ( $self, $c ) = @_;

    my $sections = $c->project->search_related('shop_sections');
    my $section;

    if ( length( my $name = $c->request->params->get('new_shop_section') // '' ) ) {
        $section = $sections->find_or_create( { name => $name } );
    }
    elsif ( my $id = $c->request->params->get('shop_section') ) {
        if ( $id ne 'null' ) {
            $section = $sections->find($id)
              or $c->detach( '/error/bad_request', ["Invalid shop section given"] );
        }
    }
    else {
        $c->detach( '/error/bad_request', ["No shop section given"] );
    }

    my @article_ids      = $c->req->params->get_all('article');
    my $project_articles = $c->project->search_related('articles');
    $project_articles->search( { $project_articles->me('id') => { -in => \@article_ids } } )
      ->update( { shop_section_id => $section ? $section->id : undef } );

    $c->stash(
        current_view => 'HTML::Snippet',
        template     => 'purchase_list/_edit_table.tt',
    );
    $c->detach('edit');
}

sub make_default : POST Chained('base') Args(0) RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $list = $c->stash->{list};

    if ( $list->is_default ) {
        $c->messages->info("Purchase list is already the project’s default purchase list.");
    }
    else {
        $list->make_default();
    }

    $c->detach('redirect');
}

sub move_items_ingredients : POST Chained('base') Args(0) RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $source_list = $c->stash->{list};

    my $target_list_id = $c->req->params->get('target_purchase_list')
      or $c->detach( '/error/bad_request', ["No target_list_id"] );

    my $target_list = $source_list->other_purchase_lists->find($target_list_id)
      or $c->detach( '/error/bad_request', ["Target purchase list not found"] );

    my ( @items, @ingredients );

    for ( [ item => $source_list->items => \@items ],
        [ ingredient => $source_list->ingredients_rs, \@ingredients ] )
    {
        my ( $key, $rs, $arrayref ) = @$_;

        my @values = $c->req->params->get_all($key);

        @$arrayref = $rs->search( { $rs->me('id') => { -in => \@values } } )->all;

        @$arrayref == @values
          or $c->detach( '/error/bad_request', ["Invalid list of $key IDs"] );
    }

    $source_list->move_items_ingredients(
        target_purchase_list => $target_list,
        items                => \@items,
        ingredients          => \@ingredients,
        ucg                  => $c->project->unit_conversion_graph,
    );

    $c->stash(
        current_view => 'HTML::Snippet',
        template     => 'purchase_list/_edit_table.tt',
    );
    $c->detach('edit');
}

sub create : POST Chained('/project/base') PathPart('purchase_lists/create') Args(0)
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $date = $c->req->params->get('date')
      or $c->detach('/error/bad_request');

    # TODO parse and verify date

    $c->stash( lists => my $lists = $c->project->purchase_lists );
    $c->stash( list  => $lists->new_result( { date => $date } ) );

    $c->detach('update');
}

sub update : POST Chained('base') Args(0) RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $name = $c->req->params->get('name') // $c->detach('/error/bad_request');

    if ( $name !~ m/\w/ ) {
        $c->messages->error("The name of a purchase list must not be empty!");
        $c->detach('redirect');
    }

    my $list        = $c->stash->{list};
    my $other_lists = $list->other_purchase_lists;

    if ( $other_lists->search( { $other_lists->me('name') => $name } )->results_exist ) {
        $c->messages->error("A purchase list with that name already exists!");
        $c->detach('redirect');
    }

    $list->name($name);
    $list->update_or_insert();

    $c->detach('redirect');
}

sub delete : POST Chained('base') Args(0) RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $list = $c->stash->{list};

    $list->txn_do(
        sub {
            ( $list->is_default and $list->other_purchase_lists->results_exist )
              and $c->detach( '/error/bad_request', ["Can't delete default purchase list"] );

            $list->delete();
        }
    );

    $c->detach('redirect');
}

sub redirect : Private {
    my ( $self, $c ) = @_;

    $c->response->redirect( $c->project_uri( $self->action_for('index') ) );
}

__PACKAGE__->meta->make_immutable;

1;
