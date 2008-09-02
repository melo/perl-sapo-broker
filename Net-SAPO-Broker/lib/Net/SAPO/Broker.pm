package Net::SAPO::Broker;

use warnings;
use strict;
use base qw( Protocol::SAPO::Broker );
use IO::Socket::INET;
use IO::Select;
use Errno qw( EWOULDBLOCK );
use Time::HiRes qw( usleep );

our $VERSION = '0.01';

sub new {
  my ($class, $args) = @_;
  my $self = $class->SUPER::new({ skip_init => 1 });

  $args ||= {};
  $args->{on_connect}   = sub { my $sb = shift; $sb->_do_connect(@_)   };
  $args->{on_reconnect} = sub { my $sb = shift; $sb->_do_reconnect(@_) };
  $args->{on_send}      = sub { my $sb = shift; $sb->_do_write(@_)     };
  
  $self->init($args);
  
  return $self;
}


### Local API

sub deliver_messages {
  my ($self, $timeout) = @_;
  $timeout ||= 0;
  
  WAIT_FOR_DATA:
  while($self->state eq 'connected') {
    my $sock = $self->info();
    my $select = IO::Select->new($sock);

    last WAIT_FOR_DATA unless $select->can_read($timeout);

    $self->_do_read();
  }
  
  return;
}


### Hooks

sub _do_connect {
  my ($self, $host, $port) = @_;
  
  my $sock = IO::Socket::INET->new(
    PeerHost => $host,
    PeerPort => $port,
    Proto    => 'tcp',
    Blocking => 1,
  );
  
  if (!$sock) {
    $self->connect_failed($!);
    return;
  }
  
  $sock->blocking(0);

  $self->connected($sock);
  delete $self->{reconnect_count};
  
  return;
}

sub _do_reconnect {
  my ($self) = @_;
  
  my $retry = ++$self->{reconnect_count};
  usleep(100000) if $retry >  3;
  usleep(100000) if $retry >  6;
  usleep(300000) if $retry > 12;
  
  return;
}

sub _do_write {
  my ($self, $msg) = @_;
  local $SIG{PIPE} = 'IGNORE';

  $self->_do_read();
  
  WRITE:
  while(1) {
    my $sock = $self->info;
    my $r = $sock->syswrite($msg);
    last if $r && $r == length($msg);
    
    if (! defined($r)) {
      if ($!{EWOULDBLOCK}) {
        my $select = IO::Select->new($sock);
        $select->can_write();
        next WRITE;
      }
      
      $self->write_error($!);
      last WRITE;
    }
    
    $msg = substr($msg, $r);
  }
  
  return;
}

sub _do_read {
  my ($self) = @_;
  
  READ:
  while (1) {
    my $data;
    my $sock = $self->info;
    my $r = $sock->sysread($data, 32_000);

    if (!defined($r)) {
      last READ if $!{EWOULDBLOCK};
      $self->read_error($!);
    }
    elsif ($r) {
      $r = $self->incoming_data($data);
      croak("Error in frame from network: $r") if $r;
    }
    else {
      $self->incoming_data(undef); # Signal EOF
      last READ;
    }
  }
  
  return;
}


=head1 NAME

Net::SAPO::Broker - The great new Net::SAPO::Broker!

=head1 VERSION

Version 0.01


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Net::SAPO::Broker;

    my $foo = Net::SAPO::Broker->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 FUNCTIONS

=head1 AUTHOR

Pedro Melo, C<< <melo at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-sapo-broker at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-SAPO-Broker>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::SAPO::Broker


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-SAPO-Broker>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-SAPO-Broker>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-SAPO-Broker>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-SAPO-Broker>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 Pedro Melo, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Net::SAPO::Broker
