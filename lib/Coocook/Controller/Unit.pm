package Coocook::Controller::Unit;

use Coocook::Base qw(Moose);

use Scalar::Util qw( looks_like_number weaken );

BEGIN { extends 'Coocook::Controller' }

=head1 NAME

Coocook::Controller::Unit - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 index

=cut

sub index : GET HEAD Chained('/project/base') PathPart('units') Args(0)
  RequiresCapability('view_project') {
    my ( $self, $c ) = @_;

    my %units_in_use;

    {
        my @resultsets = (
            $c->project->units->search_related('articles_units'),
            $c->project->items_rs,
            $c->project->dishes->search_related('ingredients'),
            $c->project->recipes->search_related('ingredients'),
        );

        for my $resultset (@resultsets) {
            my $ids = $resultset->get_column( { distinct => 'unit_id' } );

            @units_in_use{ $ids->all } = ();    # set all keys to undef
        }
    }

    my @units;

    {
        my $action = $self->action_for('delete');

        my $units = $c->project->units->search( undef, { order_by => 'long_name' } );

        while ( my $unit = $units->next ) {
            push @units,
              my $u = $unit->as_hashref( url => $c->project_uri( $self->action_for('edit'), $unit->id ) );

            # add delete_url to deletable units
            exists $units_in_use{ $unit->id }                                 # in use, for ingredient
              or $u->{delete_url} = $c->project_uri( $action, $unit->id );    # can be deleted
        }
    }

    {
        my %units            = map { $_->{id} => $_ } @units;
        my $unit_conversions = $c->project->unit_conversions->hri;

        while ( my $conversion = $unit_conversions->next ) {
            $conversion->{transitive} or die "non-transitive not implemented";
            length $conversion->{comment} and warn "comments not displayed yet";

            my $factor = $conversion->{factor};
            my $unit1  = $units{ $conversion->{unit1_id} };
            my $unit2  = $units{ $conversion->{unit2_id} };

            push $unit1->{conversions}->@*,
              {
                factor => $factor,
                unit   => $unit2,
              };

            push $unit2->{conversions}->@*, {
                factor => 1 / $factor,    # inverse
                unit   => $unit1,
            };

            weaken $unit1->{conversions}[-1]{unit};
            weaken $unit2->{conversions}[-1]{unit};
        }
    }

    $c->stash(
        create_url => $c->project_uri( $self->action_for('create') ),
        units      => \@units,
    );
}

sub base : Chained('/project/base') PathPart('unit') CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;

    $c->stash( unit => $c->project->units->find($id) || $c->detach('/error/not_found') );
}

sub edit : GET HEAD Chained('base') PathPart('') Args(0) RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $unit = $c->stash->{unit};

    my @articles = $unit->articles->sorted->hri->all;

    for my $article (@articles) {
        $article->{url} = $c->project_uri( '/article/edit', $article->{id} );
    }

    my @units = $c->project->units->hri->all;
    my %units = map { $_->{id} => $_ } @units;

    my $primary_group = [];    # the group with $unit
    my @groups;                # except primary group
    my %groups_per_unit = ( $unit->id => $primary_group );

    my $conversions = $c->project->unit_conversions->hri;

    while ( my $conversion = $conversions->next ) {
        my $unit1_id = $conversion->{unit1_id};
        my $unit2_id = $conversion->{unit2_id};

        if ( $unit1_id == $unit->id ) {
            $units{$unit2_id}{factor} = $conversion->{factor};
        }
        elsif ( $unit2_id == $unit->id ) {
            $units{$unit1_id}{factor} = $conversion->{factor}**-1;
        }

        my $group1 = $groups_per_unit{$unit1_id};
        my $group2 = $groups_per_unit{$unit2_id};

        if ($group1) {
            if ($group2) {    # both -> groups must be merged
                if ( $group2 == $primary_group ) {    # primary group must not be removed by merge
                    ( $group1, $group2 ) = ( $group2, $group1 );
                }

                push @$group1, @$group2;

                for my $group2_unit (@$group2) {
                    $groups_per_unit{ $group2_unit->{id} } = $group1;
                }

                @groups = grep { $_ ne $group2 } @groups;

            }
            else {    # only group1
                push @$group1, $units{$unit2_id};
                $groups_per_unit{$unit2_id} = $group1;
            }
        }
        elsif ($group2) {
            push @$group2, $units{$unit1_id};
            $groups_per_unit{$unit1_id} = $group2;
        }
        else {    # neither group
            my $group = [ map { $units{$_} || die $_ } $unit1_id, $unit2_id ];
            push @groups, $group;
            $groups_per_unit{$unit1_id} = $group;
            $groups_per_unit{$unit2_id} = $group;
        }
    }

    if ( keys %groups_per_unit < @units ) {    # units not related to any conversion
        push @groups, [ grep { not exists $groups_per_unit{ $_->{id} } } @units ];
    }

    for my $unit2 (@$primary_group) {
        $unit2->{url} = $c->project_uri( $self->action_for('edit'), $unit2->{id} );

        $unit2->{update_url} =
          $c->project_uri( $self->action_for('update_conversion'), $unit->id, $unit2->{id} );

        $unit2->{delete_url} =
          $c->project_uri( $self->action_for('delete_conversion'), $unit->id, $unit2->{id} );

    }

    $c->stash(
        articles           => \@articles,
        conversions        => $primary_group,
        grouped_units      => \@groups,
        update_url         => $c->project_uri( $self->action_for('update'),         $unit->id ),
        add_conversion_url => $c->project_uri( $self->action_for('add_conversion'), $unit->id ),
    );
}

sub create : POST Chained('/project/base') PathPart('units/create') Args(0)
  RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    $c->stash( unit => $c->project->new_related( units => {} ) );
    $c->detach('update_or_insert');
}

sub update : POST Chained('base') Args(0) RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    $c->detach('update_or_insert');
}

sub update_or_insert : Private {
    my ( $self, $c ) = @_;

    my $unit = $c->stash->{unit};

    $unit->set_columns(
        {
            short_name => $c->req->params->get('short_name'),
            long_name  => $c->req->params->get('long_name'),
        }
    );

    my @errors;

    length $unit->short_name
      or push @errors, "Short name must be set!";

    if ( length $unit->long_name ) {
        my $is_unique = not $c->project->units->results_exist(
            { ( $unit->in_storage ? ( id => { '!=' => $unit->id } ) : () ), long_name => $unit->long_name } );

        $is_unique or push @errors, "Another unit with that long name already exists!";
    }
    else {
        push @errors, "Long name must be set!";
    }

    # TODO keep input values
    if (@errors) {
        $c->messages->error($_) for @errors;

        $c->redirect_detach(
            $c->project_uri(
                $unit->in_storage
                ? ( $self->action_for('edit'), $unit->id )
                : $self->action_for('index')
            )
        );
    }

    $unit->update_or_insert();

    $c->detach('redirect');
}

sub delete : POST Chained('base') Args(0) RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    $c->stash->{unit}->delete();
    delete $c->stash->{unit};
    $c->detach('redirect');
}

sub add_conversion : POST Chained('base') Args(0) RequiresCapability('edit_project') {
    my ( $self, $c ) = @_;

    my $unit1 = $c->stash->{unit} || die;
    my $unit2 =
      $unit1->other_units->find( $c->req->params->get('unit2') ) || $c->detach('/error/bad_request');

    my ( $value1, $value2 ) = map { $c->req->params->get($_) } qw( value1 value2 );
    my $factor = $value2 / $value1;

    my $conversion = $unit1->conversions_from->new_result(
        {
            unit2_id => $unit2->id,
            factor   => $factor,
        }
    );

    $conversion->reverse() unless $unit1->id < $unit2->id;
    $conversion->insert();

    $c->detach('redirect');
}

sub update_conversion : POST Chained('base') Args(1) RequiresCapability('edit_project') {
    my ( $self, $c, $unit2_id ) = @_;

    my $factor = $c->req->params->get('factor') || $c->detach('/error/bad_request');
    $factor += 0;    # cast into number

    my $conversion = $c->stash->{unit}->find_conversion_into($unit2_id)
      || $c->detach('/error/not_found');

    if ( $conversion->unit2_id != $unit2_id ) {
        $factor **= -1;
    }

    $conversion->update( { factor => $factor } );

    $c->detach('redirect');
}

sub delete_conversion : POST Chained('base') Args(1) RequiresCapability('edit_project') {
    my ( $self, $c, $unit2_id ) = @_;

    my $conversion = $c->stash->{unit}->find_conversion_into($unit2_id)
      || $c->detach('/error/not_found');

    $conversion->delete();
    $c->detach('redirect');
}

sub redirect : Private {
    my ( $self, $c ) = @_;

    if ( my $unit = $c->stash->{unit} ) {
        $c->response->redirect( $c->project_uri( $self->action_for('edit'), $unit->id ) );
    }
    else {
        $c->response->redirect( $c->project_uri( $self->action_for('index') ) );
    }
}

__PACKAGE__->meta->make_immutable;

1;
