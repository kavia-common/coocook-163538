package Coocook::Schema::Component::ProxyMethods;

# ABSTRACT: call ResultSource or Schema methods by shorthand methods from Result[Set]

use Coocook::Base;

use DateTime;

# DateTime formatting
sub format_date     { shift->result_source->storage->datetime_parser->format_date(@_) }
sub format_datetime { shift->result_source->storage->datetime_parser->format_datetime(@_) }

sub format_date_today ($self) {
    $self->result_source->storage->datetime_parser->format_date( DateTime->today );
}

sub format_datetime_now ($self) {
    $self->result_source->storage->datetime_parser->format_datetime( DateTime->now );
}

# DateTime parsing
sub parse_date     { shift->result_source->storage->datetime_parser->parse_date(@_) }
sub parse_datetime { shift->result_source->storage->datetime_parser->parse_datetime(@_) }

# transactions
sub svp_begin       { shift->result_source->storage->svp_begin(@_) }
sub svp_release     { shift->result_source->storage->svp_release(@_) }
sub svp_rollback    { shift->result_source->storage->svp_rollback(@_) }
sub txn_begin       { shift->result_source->storage->txn_begin(@_) }
sub txn_commit      { shift->result_source->storage->txn_commit(@_) }
sub txn_do          { shift->result_source->storage->txn_do(@_) }
sub txn_rollback    { shift->result_source->storage->txn_rollback(@_) }
sub txn_scope_guard { shift->result_source->storage->txn_scope_guard(@_) }

# TODO this is only a workaround for issue #142
sub format_bool ( $self, $value ) {    # short, convenient method name
    defined $value or return (undef);

    return ( $value ? 1 : 0 );
}

1;
