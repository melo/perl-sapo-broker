package Protocol::SAPO::Broker::Notification;

use strict;
use warnings;
use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_ro_accessors(qw(
  sb id payload topic matched message
));

sub ack {
  my ($self, $sb) = @_;
  $sb = $self->{sb} unless $sb;

  return $sb->ack({
    id    => $self->id,
    queue => $self->matched,
  });  
}

1;
