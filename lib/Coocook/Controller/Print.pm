package Coocook::Controller::Print;

use DateTime;
use Moose;
use namespace::autoclean;
use utf8;

BEGIN { extends 'Coocook::Controller' }

=head1 NAME

Coocook::Controller::Print - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub day : GET HEAD Chained('/purchase_list/submenu') PathPart('print/day') Args(3)
  RequiresCapability('view_project') {
    my ( $self, $c, $year, $month, $day ) = @_;

    my $dt = DateTime->new(
        year  => $year,
        month => $month,
        day   => $day,
    );

    my $meals = $c->model('Plan')->day( $c->project, $dt );

    for my $meal (@$meals) {
        for my $dish ( $meal->{dishes}->@* ) {
            $dish->{url} = $c->project_uri( '/dish/edit', $dish->{id} );

            if ( my $prep_meal = $dish->{prepare_at_meal} ) {
                $prep_meal->{url} =
                  $c->project_uri( '/print/day', map { $prep_meal->{date}->$_ } qw< year month day > );
            }
        }

        for my $dish ( $meal->{prepared_dishes}->@* ) {
            $dish->{url} ||= $c->project_uri( '/dish/edit', $dish->{id} );

            my $meal = $dish->{meal};

            $meal->{url} ||= $c->project_uri( '/print/day', map { $meal->{date}->$_ } qw< year month day > );
        }
    }

    $c->stash(
        day        => $dt,
        meals      => $meals,
        title      => "Print " . $dt->strftime( $c->stash->{date_format_short} ),
        html_title => $dt->strftime( $c->stash->{date_format_long} ),
    );
}

__PACKAGE__->meta->make_immutable;

1;
