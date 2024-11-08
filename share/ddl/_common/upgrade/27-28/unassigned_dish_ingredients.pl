use Coocook::Base;

sub ( $schema, $versions ) {
    my $projects = $schema->resultset('Project');

    while ( my $project = $projects->next ) {
        my $unassigned_ingredients = $project->dish_ingredients->unassigned;

        $project->purchase_lists->results_exist or next;
        $unassigned_ingredients->results_exist  or next;

        my $i    = 1;
        my $name = sub { "Previously unassigned items" . ( $i > 1 ? " ($i)" : "" ) };
        while ( $project->purchase_lists->find( { name => $name->() } ) ) { $i++ }

        my $list = $project->create_related(
            purchase_lists => {
                date => $project->purchase_lists->default_date,
                name => $name->(),
            }
        );

        while ( my $ingredient = $unassigned_ingredients->next ) {
            $ingredient->assign_to_purchase_list( $list->id );
        }
    }
};
