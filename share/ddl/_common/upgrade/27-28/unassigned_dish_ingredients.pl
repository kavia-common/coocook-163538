use Coocook::Base;

sub ( $schema, $versions ) {
    my $projects = $schema->resultset('Project');

    while ( my $project = $projects->next ) {
        my $unassigned_ingredients = $schema->resultset('DishIngredient')->unassigned;

        $unassigned_ingredients->results_exist or next;

        my $list = $project->create_related(
            purchase_lists => {
                date => $project->purchase_lists->default_date,
                name => "Previously unassigned items"
            }
        );

        while ( my $ingredient = $unassigned_ingredients->next ) {
            $ingredient->assign_to_purchase_list($list);
        }
    }
};
