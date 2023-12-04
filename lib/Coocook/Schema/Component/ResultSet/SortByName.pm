package Coocook::Schema::Component::ResultSet::SortByName;

# ABSTRACT: provide simple $rs->sorted() with predefined sort order

use Coocook::Base;

sub sorted_by_columns { 'name' }

sub sorted ($self) {
    return $self->search(
        undef,
        {
            order_by => [ map { $self->me($_) } $self->sorted_by_columns ],
        }
    );
}

1;
