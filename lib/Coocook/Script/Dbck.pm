package Coocook::Script::Dbck;

# ABSTRACT: script for checking the database integrity just like `fsck` checks filesystems

use Coocook::Base qw(Moose);
use open ':locale';

use Coocook::Schema;
use Coocook::Util;

with 'Coocook::Script::Role::HasDebug';
with 'Coocook::Script::Role::HasSchema';
with 'MooseX::Getopt';

# columns which tend to receive the empty string '' as value in SQLite
# TODO should we automatically select all boolean and non-FK numeric columns?
our $SQLITE_NOTORIOUS_EMPTY_STRING_COLUMNS = {
    Project          => 'is_public',
    DishIngredient   => [ 'prepare',   'value' ],
    RecipeIngredient => [ 'prepare',   'value' ],
    Item             => [ 'purchased', 'value' ],
};
our $SQLITE_NUMERIC_COLUMNS = {
    DishIngredient   => 'value',
    RecipeIngredient => 'value',
    Item             => [ 'offset', 'value' ],
};

sub run ($self) {
    $self->check_schema();
    $self->check_relationships();
    $self->check_sqlite_numeric_values();
    $self->check_fc_values();
    $self->check_url_name_values();
    $self->check_unit_conversions_values();
    $self->check_missing_default_purchase_lists();
    $self->check_unassigned_dish_ingredients();
    $self->check_items_without_dish_ingredients();
    $self->check_items_values();
}

sub check_schema ($self) {
    my $live_schema = $self->_schema;

    $live_schema->storage->sqlt_type eq 'SQLite'
      or return;    # only implemented for SQLite

    my $code_schema = Coocook::Schema->connect('dbi:SQLite::memory:');
    $code_schema->deploy();

    my $sth = $code_schema->storage->dbh->table_info( undef, undef, undef, 'TABLE' );

    while ( my $table = $sth->fetchrow_hashref ) {
        my $table_name = $table->{TABLE_NAME};
        my $table_type = $table->{TABLE_TYPE};

        $table_type eq 'SYSTEM TABLE'
          and next;

        $self->_debug("Checking schema of table '$table_name' ...");

        my $live_table =
          $live_schema->storage->dbh->table_info( undef, undef, $table_name, $table_type )
          ->fetchrow_hashref;

        if ( not $live_table ) {
            warn "Table missing: '$table_name'\n";
            next;
        }

        my $code_sql = $table->{sqlite_sql};
        my $live_sql = $live_table->{sqlite_sql};

        for ( $code_sql, $live_sql ) {
            s/\s+/ /gms;    # normalize whitespace
            s/["']//g;      # ignore quote chars
        }

        $live_sql eq $code_sql
          and next;

        warn "SQL for table '$table_name' differs:\n";

        s/^/  /gm for $code_sql, $live_sql;

        warn "<" x 7,   " code\n";
        warn $code_sql, "\n";
        warn "-" x 7,   "\n";
        warn $live_sql, "\n";
        warn ">" x 7,   " live\n";
    }
}

sub check_relationships ($self) {
    my @m_n_tables = (
        { Article          => [qw< me shop_section >] },
        { ArticleTag       => [qw< article tag >] },
        { ArticleUnit      => [qw< article unit >] },
        { Dish             => [qw< meal recipe prepare_at_meal >] },
        { DishIngredient   => [ { dish => 'meal' }, qw< article unit  > ] },
        { DishTag          => [ { dish => 'meal' }, qw< tag  > ] },
        { Item             => [qw< purchase_list unit article  >] },
        { Project          => [qw< me default_purchase_list >] },
        { RecipeIngredient => [qw< recipe article unit >] },
        { RecipeTag        => [qw< recipe tag >] },
        { Tag              => [qw< me tag_group >] },
    );

    for (@m_n_tables) {
        my ( $rs_class, $joins ) = %$_;

        $self->_debug("Checking relationships from table '$rs_class' ...");

        @$joins >= 2
          or die "need 2 or more relationships to compare project IDs";

        my $rs = $self->_schema->resultset($rs_class);

        my @pk_cols = $rs->result_source->primary_columns;

        my @tables = map { ref $_ ? values %$_ : $_ } @$joins;

        # tables except table 'projects' (its 'id' is already in @pk_cols)
        my @tables_except_projects = grep { not( $rs_class eq 'Project' and $_ eq 'me' ) } @tables;

        $rs = $rs->search(
            undef,
            {
                columns => {
                    (
                        map { $_ => $_ }    # id => id
                          @pk_cols
                    ),
                    (
                        map { $_ . '_project' => $_ . '.project_id' }    # recipe_project => recipe.project_id
                          @tables_except_projects
                    ),
                },
                join => [ grep { $_ ne 'me' } @$joins ],
            }
        )->hri;

      ROW: while ( my $row = $rs->next ) {

            # TODO optimize: hardcode which 'project' col IS NOT NULL->no need to search
            my ($master_rel) = grep { defined $row->{ $_ . '_project' } } @tables
              or die "this shouldn't happen";

            my $project_id = $row->{ $master_rel . '_project' }
              or die;

            for my $rel (@tables) {
                $rel eq $master_rel
                  and next;

                my $val =
                  ( $rs_class eq 'Project' and $rel eq 'me' )
                  ? $row->{id}
                  : ( $row->{ $rel . '_project' } // next );

                if ( $val != $project_id ) {
                    warn sprintf "Project IDs differ for %s row (%s): %s\n", $rs_class,
                      join( ", ", map { "$_ = " . $row->{$_} } @pk_cols ),
                      join( ", ",
                        map { $_ . ".project = " . ( $row->{ $_ . '_project' } // "NULL" ) } @tables_except_projects );

                    next ROW;
                }
            }
        }
    }
}

sub check_sqlite_numeric_values ($self) {

    # only SQLite has weak typing
    $self->_schema->storage->sqlt_type eq 'SQLite'
      or return;

    for my $rs ( sort keys %$SQLITE_NOTORIOUS_EMPTY_STRING_COLUMNS ) {
        my @cols = map { ref ? @$_ : $_ } $SQLITE_NOTORIOUS_EMPTY_STRING_COLUMNS->{$rs};

        for my $col (@cols) {
            my $count = $self->_schema->resultset($rs)->search( { $col => '' } );

            $count > 0
              and warn "Found $count rows with column '$col' being empty string '' in table $rs\n";
        }
    }

    for my $rs ( sort keys %$SQLITE_NUMERIC_COLUMNS ) {
        my @cols = map { ref ? @$_ : $_ } $SQLITE_NUMERIC_COLUMNS->{$rs};

        for my $col (@cols) {
            my $rows = $self->_schema->resultset($rs)->search( { $col => { -like => '%,%' } } );

            while ( my $row = $rows->next ) {
                warn sprintf "$rs ID %i has invalid number format $col='%s'\n", $row->id, $row->$col;
            }
        }
    }
}

sub check_fc_values ($self) {
    my $organizations = $self->_schema->resultset('Organization');
    my $usernames_fc  = $self->_schema->resultset('User')->get_column('name_fc');

    my $duplicates = $organizations->search( { name_fc => { -in => $usernames_fc->as_query } } )->hri;

    while ( my $duplicate = $duplicates->next ) {
        warn sprintf "Duplicate organization/user name '%s'\n", $duplicate->{name};
    }

    for my $table (qw< Organization User >) {
        my $rs = $self->_schema->resultset($table);

        while ( my $row = $rs->next ) {
            $row->name_fc eq fc( $row->name )
              or warn sprintf( "Incorrect name_fc for $table '%s': '%s'\n", $row->name, $row->name_fc );
        }
    }
}

sub check_url_name_values ($self) {
    my $projects = $self->_schema->resultset('Project');

    while ( my $project = $projects->next ) {
        $project->url_name eq Coocook::Util::url_name( $project->name )
          or warn sprintf "Incorrect url_name for project '%s': '%s'\n", $project->name, $project->url_name;

        $project->url_name_fc eq Coocook::Util::url_name( fc $project->name )
          or warn sprintf "Incorrect url_name_fc for project '%s': '%s'\n", $project->name,
          $project->url_name_fc;
    }
}

sub check_unit_conversions_values ($self) {
    my $count = $self->_schema->resultset('UnitConversion')->count(
        {
            unit1_id => { '>' => { -ident => 'unit2_id' } },
        }
    );

    if ( $count > 0 ) {
        warn sprintf "%i rows in unit_conversions not normalized: unit1_id > unit2_id\n", $count;
    }
}

sub check_missing_default_purchase_lists ($self) {
    my $projects = $self->_schema->resultset('Project');

    $projects = $projects->search(
        {
            -and => [
                { default_purchase_list_id => undef },
                $projects->correlate('purchase_lists')->results_exist_as_query,
            ]
        }
    );

    while ( my $project = $projects->next ) {
        warn sprintf "Project %i has purchase list(s) but its default_purchase_list_id is NULL",
          $project->id;
    }
}

sub check_unassigned_dish_ingredients ($self) {
    my $projects         = $self->_schema->resultset('Project');
    my $invalid_projects = $projects->search(
        {
            -and => [
                $projects->correlate('purchase_lists')->results_exist_as_query,
                $projects->correlate('meals')->search_related('dishes')->search_related('ingredients')
                  ->unassigned->results_exist_as_query,
            ]
        }
    );

    while ( my $project = $invalid_projects->next ) {
        warn sprintf "Project %i has purchase list(s) but also unassigned dish ingredients", $project->id;
    }
}

sub check_items_without_dish_ingredients ($self) {
    my $items     = $self->_schema->resultset('Item');
    my $bad_items = $items->search(
        {
            -not_bool => $items->correlate('ingredients')->results_exist_as_query,
        },
        {
            columns  => [ 'id', 'value' ],
            prefetch => 'purchase_list',
        }
    );

    while ( my $item = $bad_items->next ) {
        warn sprintf "Item %i in project %i has no dish ingredients%s",
          $item->id,
          $item->purchase_list->project_id,
          $item->value == 0 ? '' : " but a non-zero value";
    }
}

sub check_items_values ($self) {
    my $items       = $self->_schema->resultset('Item');
    my $ingredients = $items->correlate('ingredients');

    my $value_subquery =
      $ingredients->search( { $ingredients->me('unit_id') => { -ident => $items->me('unit_id') } } )
      ->get_column('value')->sum_rs->as_query;

    # DBIC doesn't support SQL alias for subquery
    # https://stackoverflow.com/a/3429954
    #
    # result of as_query() is a scalarref with an arrayref with a string: ["(SELECT ...)"]
    $$value_subquery->[0] .= q{ AS "value_sum_sql" };

    my $bad_items = $items->search(
        {
            $items->me('value') => { '<' => { -ident => 'value_sum_sql' } },
        },
        {
            join       => 'unit',
            '+columns' => {
                value_sum         => $value_subquery,
                'unit_short_name' => 'unit.short_name',
            },
        }
    );

    while ( my $item = $bad_items->next ) {
        warn sprintf "Item %i has value of %g%s < %g%s the sum of its ingredients",
          $item->id,
          $item->value,
          $item->get_column('unit_short_name'),
          $item->get_column('value_sum'),
          $item->get_column('unit_short_name');
    }
}

sub _debug ( $self, @list ) {
    $self->debug
      or return;

    local $| = 1;

    print @list, "\n";
}

__PACKAGE__->meta->make_immutable;

1;
