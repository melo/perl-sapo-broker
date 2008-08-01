package Net::SAPO::Broker;

use warnings;
use strict;
use Protocol::SAPO::Broker;
use IO::Socket::INET;

our $VERSION = '0.01';

sub new {
  my ($class, $args) = @_;
  my $self = bless {}, $class;

  $args ||= {};
  $args->{on_connect} = sub { $self->_do_connect(@_) };
  
  $self->{psb} = Protocol::SAPO::Broker->new($args);
  
  return $self;
}

sub state { return $_[0]{psb}->state }

sub _do_connect {
  my ($self, $sbp, $host, $port) = @_;
  
  my $sock = IO::Socket::INET->new(
    PeerHost => $host,
    PeerPort => $port,
    Proto    => 'tcp',
    Blocking => 1,
  );
  
  if (!$sock) {
    $sbp->connect_failed($!);
    return;
  }
  
  $sbp->connected($sock);
  
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