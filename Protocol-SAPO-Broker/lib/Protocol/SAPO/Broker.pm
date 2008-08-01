package Protocol::SAPO::Broker;

use warnings;
use strict;
use Carp::Clan qw(Protocol::SAPO::Broker);

our $VERSION = '0.01';

sub new {
  my ($class, $args) = @_;
  $args ||= {};
  
  # Agent location
  my $host = $args->{host} || '127.0.0.1';
  my $port = $args->{port} || 3322;
  
  # Auto-connect flags
  my $auto_conn = exists $args->{auto_connect}? $args->{auto_connect} : 1;
  
  # extract callbacks
  my %cbs;
  while (my ($k, $v) = each %$args) {
    next unless $k =~ m/^on_(.+)/;
    $cbs{$1} = $v;
  }
  
  # Create protocol state machine
  my $self = bless {
    state     => 'idle',
    host      => $host,
    port      => $port,
    auto_conn => $auto_conn,
    cb        => \%cbs,
  }, $class;
  
  # Do auto-connect if asked for
  $self->connect() if $auto_conn;
  
  return $self;
}


sub connect {
  my ($self) = @_;

  $self->_set_state('connecting');  
  $self->_callback('connect', $self->{host}, $self->{port});
}

sub disconnect {
  my ($self) = @_;

  $self->_set_state('disconnecting');  
  $self->_optional_callback('disconnect', $self->{info});
  
  delete $self->{info};
  $self->_set_state('idle');
}


### Client reporting methods

sub connected {
  my ($self, $info) = @_;
  
  $self->_set_state('connected');
  $self->{info} = $info;
  delete $self->{error};
  
  $self->_optional_callback('connected', $info);
}

sub connect_failed {
  my ($self, $error) = @_;
  
  $self->{error} = $error;
  $self->_set_state('connect_error');
  
  $self->_optional_callback('connect_error', $error);
  
  $self->_set_state('idle');
}


### State machine

sub _set_state {
  my ($self, $new_state) = @_;
  
  $self->{state} = $new_state;
}


### Callback logic

sub _callback {
  my ($self, $tag, @args) = @_;
  
  croak("Missing callback '$tag', ") unless $self->{cb}{$tag};

  return $self->_optional_callback($tag, @args);
}

sub _optional_callback {
  my ($self, $tag, @args) = @_;
  
  my $cb = $self->{cb}{$tag};
  return unless $cb;

  return $cb->($self, @args);
}


### Accessors

sub state { return $_[0]{state} }
sub host  { return $_[0]{host}  }
sub port  { return $_[0]{port}  }
sub info  { return $_[0]{info}  }
sub error { return $_[0]{error} }

=head1 NAME

Protocol::SAPO::Broker - The great new Protocol::SAPO::Broker!

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Protocol::SAPO::Broker;

    my $foo = Protocol::SAPO::Broker->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 FUNCTIONS

=head1 AUTHOR

Pedro Melo, C<< <melo at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-protocol-sapo-broker at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Protocol-SAPO-Broker>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Protocol::SAPO::Broker


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Protocol-SAPO-Broker>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Protocol-SAPO-Broker>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Protocol-SAPO-Broker>

=item * Search CPAN

L<http://search.cpan.org/dist/Protocol-SAPO-Broker>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 Pedro Melo, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Protocol::SAPO::Broker
