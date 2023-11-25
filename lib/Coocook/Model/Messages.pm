package Coocook::Model::Messages;

use Coocook::Base;

use Carp;

my @types = qw<
  debug
  info
  warn
  error
>;

my %types = map { $_ => undef } @types;

for my $type (@types) {
    my $method = sub {
        my $self = shift;

        my %message = @_ == 1 ? ( text => $_[0] ) : @_;

        $message{type} = $type;

        push @$self, \%message;
    };

    no strict 'refs';
    *{ __PACKAGE__ . '::' . $type } = $method;
}

=head1 CONSTRUCTORS

=head2 new

=cut

sub new ($class) {
    return bless [], $class;
}

=head1 METHODS

=head2 add(\%message)

=head2 add("$text")

=head2 add(%message)

=cut

sub add ( $self, @args ) {
    my %message = @args == 1 ? $args[0]->%* : @args;

    if ( keys %message == 1 ) {
        my ( $type => $text ) = %message;

        exists $types{$type} or croak "Unsupported type";

        %message = ( type => $type, text => $text );
    }
    else {
        exists $message{type}
          or croak "Argument 'type' required";

        exists $message{text}
          or exists $message{html}
          or croak "Arguments 'text' or 'html' required";
    }

    push @$self, \%message;

    return $self;
}

=head2 clear()

Removes all messages.

=cut

sub clear ($self) {
    @$self = ();
    return $self;
}

=head2 messages()

Returns unblessed array reference.

=cut

sub messages ($self) { [@$self] }

=head2 next()

=cut

sub next ($self) { shift @$self }

1;
