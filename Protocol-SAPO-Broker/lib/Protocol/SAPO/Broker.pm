package Protocol::SAPO::Broker;

use warnings;
use strict;
use Carp::Clan qw(::SAPO::Broker$);
use Errno qw( ENOTCONN EPROTONOSUPPORT );
use XML::LibXML;
use XML::LibXML::XPathContext;

our $VERSION = '0.01';

sub new {
  my ($class, $args) = @_;
  $args ||= {};
  
  my $self = bless {}, $class;

  return $self->init($args) unless delete $args->{skip_init};
  return $self;
}

sub init {
  my ($self, $args) = @_;
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
  
  # Init protocol state machine
  $self->{state}     = 'idle';
  $self->{host}      = $host;
  $self->{port}      = $port;
  $self->{auto_conn} = $auto_conn;
  $self->{cb}        = \%cbs;

  # Do auto-connect if asked for
  $self->connect() if $auto_conn;
  
  return $self;
}


### SAPO Broker API

sub connect {
  my ($self) = @_;

  $self->_set_state('connecting');  
  return $self->_callback('connect', $self->{host}, $self->{port});
}

sub disconnect {
  my ($self) = @_;

  $self->_set_state('disconnecting');  
  $self->_optional_callback('disconnect', $self->{info});

  foreach my $field (qw( info expect buffer frame_length )) {
    delete $self->{$field};
  }
  $self->_set_state('idle');
  
  return;
}

sub publish {
  my $self = shift;
  
  my $args = _parse_common_args(@_);
  
  croak("Missing required parameter 'topic', ")
    unless $args->{topic};
  croak("Missing required parameter 'payload', ")
    unless exists $args->{payload};

  # If present the message ID is also used as ack_id
  # It will only be used if ack's where requested!
  $args->{ack_id} = $args->{id};

  return $self->_send_message({
    %$args,
    mesg      => 'Publish',
    wrapper   => 'BrokerMessage',
  });
}

sub subscribe {
  my $self = shift;
  my $args = _parse_common_args(@_);
  
  croak("Missing required parameter 'topic', ")
    unless $args->{topic};

  my $dest_name = delete $args->{topic};
  my $dest_type = 'TOPIC';
  
  # The ID is to be used as ack_id only
  # It will only be used if ack's where requested!
  $args->{ack_id} = delete $args->{id};
  
  if (my $queue_name = delete $args->{as_queue}) {
    $dest_name = "$queue_name\@$dest_name";
    $dest_type = 'TOPIC_AS_QUEUE';
  }
  
  if (my $cb = delete $args->{on_message}) {
    my $subs = $self->{subs}{$dest_name} ||= [];
    push @$subs, $cb;
  }

  return $self->_send_message({
    %$args,
    mesg      => 'Notify',
    topic     => $dest_name,
    dest_type => $dest_type,
  });
}

sub _parse_common_args {
  my ($args) = @_;
  my %clean;
  
  foreach my $f (qw( topic payload ack as_queue id
                     on_message on_success on_error )) {
    $clean{$f} = $args->{$f} if exists $args->{$f};
  }
  
  foreach my $f (qw( on_success on_error on_message )) {
    croak("Parameter '$f' must be a CODE ref, ")
      if exists $clean{$f} && ref($clean{$f}) ne 'CODE';
  }

  # Enable ack if we ask for feedback
  foreach my $f (qw( on_success on_error )) {
    $clean{ack} = 1 if exists $clean{$f};
  }

  # Check for valid queue ID
  croak("Missing valid parameter 'as_queue', ")
    if exists $clean{as_queue} && !$clean{as_queue};
  
  return \%clean;
}


### Protocol: SOAP Messages

sub _send_message {
  my ($self, $args) = @_;
  
  return $self->_set_error(ENOTCONN) if $self->state ne 'connected';

  # Start SOAP header  
  my $soap_msg
    = q{<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"><s:Body>};
  
  # Add message type
  my $mesg = $args->{mesg};
  if ($args->{ack}) {
    my $ack_id = $args->{ack_id};
    $ack_id = _gen_action_id() unless $ack_id;
    $mesg .= qq{ b:action-id="$ack_id"};

    # We shall be waiting for your call
    $self->{id_callbacks}{$ack_id} = [
      $args->{on_success},
      $args->{on_error},
    ];    
  }
  $soap_msg .= qq{<b:$mesg xmlns:b="http://services.sapo.pt/broker">};
  
  # Some messages require a wrapper, like Publish
  my $wrapper = $args->{wrapper};
  $soap_msg .= "<b:$wrapper>" if $wrapper;
  
  # Generate MessageId header
  my $id = $args->{id};
  $soap_msg .= qq{<b:MessageId>$id</b:MessageId>} if $id;
  
  # Order of the nodes is important! Specified as a SEQUENCE-OF in the WSDL
  # Deal with destination name (mandatory) and type (optional)
  $soap_msg .= qq{<b:DestinationName>$args->{topic}</b:DestinationName>};
  $soap_msg .= qq{<b:DestinationType>$args->{dest_type}</b:DestinationType>}
    if $args->{dest_type};

  # text payload, make sure proper XML encoding
  if (exists $args->{payload}) {
    $soap_msg 
      .= q{<b:TextPayload>}
      .  _exml($args->{payload} || '')
      .  q{</b:TextPayload>};
  }
  
  # message trailer
  $soap_msg .= "</b:$wrapper>" if $wrapper;
  $soap_msg
    .= qq{</b:$args->{mesg}>}
    .  q{</s:Body></s:Envelope>};

  # wire-level frame: lenght prefix + payload
  substr( $soap_msg, 0, 0 ) = pack( 'N', length($soap_msg) );
  
  return $self->_callback('send', $self->{info}, $soap_msg);
}

sub _receive_message {
  my ($self, $payload) = @_;
  
  $self->_optional_callback('receive', $payload);
  
  # Parse the XML
  my $xdoc = eval { _parse_xml($payload) };
  if (my $e = $@) {
    $self->_set_error(EPROTONOSUPPORT);    
    return $self->_optional_callback('payload_error', $payload, $e);
  }

  # Register most important namespaces
  $xdoc->registerNs( mysoap => 'http://www.w3.org/2003/05/soap-envelope' );
  $xdoc->registerNs( mymq   => 'http://services.sapo.pt/broker'          );
  $xdoc->registerNs( mywsa  => 'http://www.w3.org/2005/08/addressing'    );

  # Check to see if it is a valid Broker message
  my ($msg) = $xdoc->findnodes('//mysoap:Body/mymq:*');
  return $self->_process_message($msg, $payload, $xdoc) if $msg;
  
  # Ok, not a BrokerMessage, maybe a Fault?
  my ($fault) = $xdoc->findnodes('//mysoap:Fault');
  return $self->_process_fault($fault, $xdoc) if $fault;
  
  # WTF is this?
  return $self->_optional_callback('unknown_payload', $payload, $xdoc);
}

sub _process_message {
  my ($self, $mesg, $payload, $xdoc) = @_;
  
  my $node_name = $mesg->localname;
  return $self->_process_notification($mesg, $xdoc)
    if $node_name eq 'Notification';
  return $self->_process_accepted($mesg, $xdoc)
    if $node_name eq 'Accepted';
  
  return $self->_optional_callback('unknown_message', $mesg, $payload);
}

sub _process_notification {
  my ($self, $mesg, $xdoc) = @_;
  
  my $destination = $xdoc->findvalue('//mymq:DestinationName', $mesg);
  my $payload     = $xdoc->findvalue('//mymq:TextPayload', $mesg);
  my $to          = $xdoc->findvalue('//mywsa:To') || $destination;
  
  $destination =~ s/^[^@]+[@]//;

  return $self->_optional_callback('unmatched_message', $payload, $destination, $mesg, $xdoc)
    unless exists $self->{subs}{$to};
    
  my $subs = $self->{subs}{$to};
  foreach my $cb (@$subs) {
    $cb->($self, $payload, $destination, $mesg, $xdoc);
  }
  
  return;
}

sub _process_accepted {
  my ($self, $mesg, $xdoc) = @_;

  my ($ack) = $xdoc->findnodes('//mymq:Accepted', $mesg);
  my $id = $ack->getAttributeNS('http://services.sapo.pt/broker', 'action-id');
  
  my $cbs = delete $self->{id_callbacks}{$id};
  $cbs->[0]->($self, $id, $mesg, $xdoc) if $cbs && $cbs->[0];
  
  return;
}

sub _process_fault {
  my ($self, $fault, $xdoc) = @_;
  my %fault;
  
  my %fields = (
    code    => ['Code', 'Value'],
    subcode => ['Code', 'Subcode', 'Value'],
    reason  => ['Reason', 'Text'],
    detail  => ['Detail'],
  );
  
  while (my ($field, $xp) = each %fields) {
    my $xpath = join('/', map { "mysoap:$_" } @$xp);
    $fault{$field} = $xdoc->findvalue($xpath, $fault);
  }
  
  if ($fault{subcode}) {
    my $id = $fault{subcode};
    
    my $cbs = delete $self->{id_callbacks}{$id};
      
    $cbs->[1]->($self, $id, $fault, $xdoc) if $cbs && $cbs->[1];
  }
  
  return $self->_optional_callback('fault', \%fault, $xdoc);
}


### Implementation reporting methods

sub connected {
  my ($self, $info) = @_;
  
  $self->_set_state('connected');
  $self->_set_error(undef);
  $self->{info} = $info;
  $self->{buffer} = '';
  $self->{expect} = 0; # N=0 - expects new frame, N > 0 expects N bytes of frame
  
  return $self->_optional_callback('connected', $info);
}

sub connect_failed {
  my ($self, $error) = @_;
  
  $self->_set_error($error);
  $self->_set_state('connect_error');
  $self->_optional_callback('connect_error', $error);
  
  $self->_set_state('idle');
  
  return;
}

sub incoming_data {
  my ($self, $data) = @_;

  # Clear previous error
  $self->_set_error(undef);
  
  # Deal with EOF
  if (!defined($data)) { # EOF
    $self->_optional_callback('eof', $self);
    $self->disconnect;
    return;
  }
  
  croak("Cannot give me incoming data when state is not 'connected', ")
    unless $self->{state} eq 'connected';
  
  my $buf = $self->{buffer} .= $data;
  my $exp = $self->{expect};
  my $nfl = $self->{frame_length};
  my $lbf = length($buf);
  
  # Slice multiple frames, until we run out of data
  while (1) {
    if (!$exp) { # expecting 4 bytes for payload size
      last unless $lbf > 4;
      
      $nfl = $exp = unpack('N', substr($buf, 0, 4, ''));
      $lbf -= 4;
    }
    else { # Expecting payload of size $exp
      $exp = $nfl - $lbf;
      last if $exp > 0; # not enough data

      my $payload = substr($buf, 0, $nfl, '');
      $lbf -= $nfl;
      $exp = $nfl = 0;
      $self->_receive_message($payload);
    }
  }
  
  $self->{buffer} = $buf;
  $self->{expect} = $exp;
  $self->{frame_length} = $nfl;
  
  return;
}

sub write_error {
  my ($self, $error) = @_;

  $self->_set_error($error);
  $self->_set_state('write_error');
  
  $self->_optional_callback('write_error', $error);

  return $self->disconnect;
}

sub read_error {
  my ($self, $error) = @_;

  $self->_set_error($error);
  $self->_set_state('read_error');
  
  $self->_optional_callback('read_error', $error);

  return $self->disconnect;
}


### State machine

sub _set_state {
  my ($self, $new_state) = @_;
  
  $self->{state} = $new_state;
}


### Error handling

sub _set_error {
  my ($self, $err) = @_;
  
  return delete($self->{error}) unless defined $err;
  return $self->{error} = $! = $err;
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

  $cb->($self, @args);
  
  return $self->{error};
}


### Accessors

sub state  { return $_[0]{state} }
sub host   { return $_[0]{host}  }
sub port   { return $_[0]{port}  }
sub info   { return $_[0]{info}  }
sub error  { return $_[0]{error} }
sub expect { return $_[0]{expect} }
sub buffer { return $_[0]{buffer} }



### XML utils

sub _exml {
  my $x = shift;
  
  return $x unless $x;
  
  $x =~ s/&/&amp;/g;
  $x =~ s/</&lt;/g;
  $x =~ s/>/&gt;/g;
  
  return $x;
}

my $xml_parser;

sub _parse_xml {
  my ($xml) = @_;
  
  $xml_parser = XML::LibXML->new unless $xml_parser;
  
  my $doc = $xml_parser->parse_string($xml);
  $doc->indexElements;
  return XML::LibXML::XPathContext->new($doc);
}


### ID generators

my $id_count = 0;

sub _gen_action_id {
  $id_count++;
  my $t = time();
  return "$^T-$t-$$-$id_count";
}

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
