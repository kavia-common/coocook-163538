package Coocook::Schema::ResultSet::RecipeOfTheDay;

use Coocook::Base qw(Moose);

extends 'Coocook::Schema::ResultSet';

__PACKAGE__->meta->make_immutable;

=head2 today( pick=>n? )

Returns all C<Result::RecipeOfTheDay> objects for today.
On request picks up to I<n> public recipes at random.

The linked C<Result::Recipe> is always prefetched.

For a C<ResultSet> object as return value a different
C<today_rs> method would be required.

=cut

sub today ( $self, %opts ) {
    my $date = $self->format_date_today;

    my $today_rs = $self->search( { day => $date }, { prefetch => 'recipe' } );

    my @rotd = $today_rs->all;

    if ( $opts{pick} and @rotd < int $opts{pick} ) {
        my $recipes = $self->result_source->schema->resultset('Recipe')->public;

        my @new_recipes =
          $recipes->rand->search(
            { $recipes->me('id') => { -not_in => $today_rs->get_column('recipe_id')->as_query } },
            { rows               => int $opts{pick} - @rotd } )->all;

        for my $recipe (@new_recipes) {
            my $rotd =
              $recipe->create_related(
                recipe_of_the_day => { day => $date, admin_comment => "picked randomly" } );

            $rotd->recipe($recipe);    # set cache

            push @rotd, $rotd;
        }
    }

    return @rotd;
}

1;
