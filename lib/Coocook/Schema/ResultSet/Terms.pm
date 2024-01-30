package Coocook::Schema::ResultSet::Terms;

use Coocook::Base qw(Moose);

use DateTime;

extends 'Coocook::Schema::ResultSet';

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head2 order(±1)

=over 4

=item * B<-1:> from newest to oldest

=item * B<+1:> from oldest to newest

=back

=cut

sub order ( $self, $order ) {
    return $self->search( undef,
        { order_by => { ( $order < 0 ? '-DESC' : '-ASC' ) => 'valid_from' } } );
}

sub valid_on_date_rs ( $self, $date ) {
    return $self->search( { valid_from => { '<=' => ref $date ? $self->format_date($date) : $date } },
        { order_by => { -DESC => 'valid_from' } } );
}

sub valid_on_date ( $self, @args ) { $self->valid_on_date_rs(@args)->one_row }

sub valid_today_rs ($self) { $self->valid_on_date_rs( DateTime->today ) }

sub valid_today ($self) { $self->valid_on_date_rs( DateTime->today )->one_row }

1;
