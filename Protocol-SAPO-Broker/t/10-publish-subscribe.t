#!perl -T

use strict;
use warnings;
use Test::More tests => 97;
use Test::Exception;
use Errno qw( ENOTCONN );

BEGIN {
	use_ok( 'Protocol::SAPO::Broker' );
}

diag( "Testing Protocol::SAPO::Broker $Protocol::SAPO::Broker::VERSION, Perl $], $^X, PID $$" );

my $sb;

my $conn = 0;
my $msg = '';
$sb = Protocol::SAPO::Broker->new({
  host => '127.0.0.2',
  port => '2233',
  auto_connect => 0,
  on_connect => sub { my $lsb = shift; return $lsb->connected($$) },
  on_send    => sub { (undef, undef, $msg) = @_; return },
});
ok($sb, 'Created a Protocol::SAPO::Broker instance with some paremeters');
is($sb->host,  '127.0.0.2',   '... with correct given host');
is($sb->port,  '2233',        '... with correct given port');
is($sb->state, 'idle',        '... proper initial state');

# try publish on non-connected sb
my $r = $sb->publish({ topic => 'test', payload => 'me' });
my $e = $!;
ok($r, 'We get an error back if publish without connected SB');
ok($r == ENOTCONN, '... proper error, ENOTCONN');
is($e, $r,         '... also set $!');
is($sb->error, $r, '... and $self->error');

# Connect
$sb->connect;
is($sb->state, 'connected',   'Now we are connected');
is($sb->info,  $$,            '... proper opaque info set');

# Publish stuff
$msg = '';
$r = $sb->publish({
  topic => '/test',
  payload => 'me',
});
ok(! defined($r), 'Publish went prety well');
ok(
  $msg =~ m!<b:Publish xmlns:b=["']http://services.sapo.pt/broker["']><b:BrokerMessage!,
  '... correct message type',
);
ok($msg =~ m!<b:DestinationName>/test</b:DestinationName!, '... proper destination');
ok($msg =~ m!<b:TextPayload>me</b:TextPayload>!,           '... proper payload');

# Publish stuff with ack
$msg = '';
$r = $sb->publish({
  topic => '/test',
  payload => 'me',
  ack => 1,
});
ok(! defined($r), 'Publish went prety well');
ok(
  $msg =~ m!<b:Publish b:action-id=["'][\w\d-]+["'] xmlns:b=["']http://services.sapo.pt/broker["']><b:BrokerMessage!,
  '... correct message type',
);
ok($msg =~ m!<b:DestinationName>/test</b:DestinationName!, '... proper destination');
ok($msg =~ m!<b:TextPayload>me</b:TextPayload>!,           '... proper payload');

# Publish stuff - emtpy payload
$msg = '';
$r = $sb->publish({
  topic => '/test',
  payload => '',
});
ok(! defined($r), 'Empty payload publish went prety well');
ok($msg =~ m!<b:DestinationName>/test</b:DestinationName!, '... proper destination');
ok($msg =~ m!<b:TextPayload></b:TextPayload>!,             '... proper payload');

# Publish stuff - undef payload
$msg = '';
$r = $sb->publish({
  topic => '/test2',
  payload => undef,
});
ok(! defined($r), 'Undefined payload publish went prety well');
ok($msg =~ m!<b:DestinationName>/test2</b:DestinationName!, '... proper destination');
ok($msg =~ m!<b:TextPayload></b:TextPayload>!,              '... proper payload');

# TODO: add tests for well formed XML and probably some XPath goodness

# Now lets fire up a subscriber connection

my ($msg_s, $i_msg_s);
my ($missed_pay, $missed_dest, $mesg, $xdoc, $bp);
my $sb_consumer = Protocol::SAPO::Broker->new({
  host => '127.0.0.2',
  port => '2233',
  auto_connect => 1,
  on_connect => sub { my $lsb = shift; return $lsb->connected($$ % 13) },
  on_send    => sub { (undef, undef, $msg_s) = @_; return },
  on_receive => sub { (undef, $i_msg_s) = @_; return },
  on_unmatched_message => sub {
    (undef, $missed_pay, $missed_dest, $mesg, $xdoc, $bp) = @_;
    return;
  },
});
ok($sb, 'Created a Protocol::SAPO::Broker instance for subscriber');
is($sb_consumer->host,  '127.0.0.2',   '... with correct given host');
is($sb_consumer->port,  '2233',        '... with correct given port');
is($sb_consumer->state, 'connected',   '... proper initial state');
is($sb_consumer->info, $$ % 13,        '... proper connection state');

# Subscribe a topic
$r = $sb_consumer->subscribe({ topic => '/test2' });
ok(! defined($r), 'Sent subscription request');
ok(
  $msg_s =~ m!<b:Notify xmlns:b=["']http://services.sapo.pt/broker["']><b:De!,
  '... correct message type',
);
ok(
  $msg_s =~ m!<b:DestinationName>/test2</b:DestinationName>!,
  '... correct destination /test2',
);
ok(
  $msg_s =~ m!<b:DestinationType>TOPIC</b:DestinationType>!,
  '... correct type TOPIC',
);

# Subscribe a topic with ack
$r = $sb_consumer->subscribe({ topic => '/test2', ack => 1 });
ok(! defined($r), 'Sent subscription request');
ok(
  $msg_s =~ m!<b:Notify b:action-id=["'][\w\d-]+["'] xmlns:b=["']http://services.sapo.pt/broker["']>!,
  "... correct message type ($msg_s)",
);
ok(
  $msg_s =~ m!<b:DestinationName>/test2</b:DestinationName>!,
  '... correct destination /test2',
);
ok(
  $msg_s =~ m!<b:DestinationType>TOPIC</b:DestinationType>!,
  '... correct type TOPIC',
);

# Subscribe a topic as queue
$r = $sb_consumer->subscribe({ topic => '/test3', as_queue => 'q3' });
ok(! defined($r), 'Sent subscription request for topic as queue');
ok(
  $msg_s =~ m!<b:Notify xmlns:b=["']http://services.sapo.pt/broker["']><b:De!,
  '... correct message type',
);
ok(
  $msg_s =~ m!<b:DestinationName>q3@/test3</b:DestinationName>!,
  '... correct destination q3@/test3',
);
ok(
  $msg_s =~ m!<b:DestinationType>TOPIC_AS_QUEUE</b:DestinationType>!,
  '... correct type TOPIC_AS_QUEUE',
);

# Subscribe a topic as queue with ack
$r = $sb_consumer->subscribe({ topic => '/test3', as_queue => 'q3', ack => 1 });
ok(! defined($r), 'Sent subscription request for topic as queue');
ok(
  $msg_s =~ m!<b:Notify b:action-id=["'][\w\d-]+["'] xmlns:b=["']http://services.sapo.pt/broker["']>!,
  '... correct message type',
);
ok(
  $msg_s =~ m!<b:DestinationName>q3@/test3</b:DestinationName>!,
  '... correct destination q3@/test3',
);
ok(
  $msg_s =~ m!<b:DestinationType>TOPIC_AS_QUEUE</b:DestinationType>!,
  '... correct type TOPIC_AS_QUEUE',
);


# Message from a unkown subscription
my $inv_topic = 'no_such_topic';
my $inv_payload = 'oh my little payload';
my $msg_ukn_subs = _mk_notification($inv_topic, $inv_payload);
$r = $sb_consumer->incoming_data(_build_frame($msg_ukn_subs));
ok(!defined($r),              'Incoming message, frame ok');
is($i_msg_s, $msg_ukn_subs,   '... proper payload');
is($missed_pay, $inv_payload, '... and properly missed, no hook for her');
is($missed_dest, $inv_topic,  '... in the proper unmatched topic');
is(ref($mesg),  'XML::LibXML::Element', 'Proper class in message parameter');
is(ref($xdoc),  'XML::LibXML::XPathContext', 'Proper class in XPath parameter');
ok($bp,         'SAPO Broker namespace prefix is defined');
ok(length($bp), '... and has something in it');


# Subscribe with callback, receive notif, check if matched
my $valid_topic = '/real_test';
my ($cb1_sb, $cb1_pay, $cb1_dest, $cb1_mesg, $cb1_xdoc, $cb1_bp);
$r = $sb_consumer->subscribe({
  topic => $valid_topic,
  callback => sub {
    ($cb1_sb, $cb1_pay, $cb1_dest, $cb1_mesg, $cb1_xdoc, $cb1_bp) = @_;
    return;
  },
});


# Message from a unkown subscription
$r = $sb_consumer->incoming_data(
  _build_frame(
    _mk_notification(
      $inv_topic, $inv_payload,
    )
  )
);
ok(! defined($r), 'Sent Notif with active subscription, but wrong topic');
isnt($cb1_pay, $inv_payload, '... and our active subscription didnt catch it');
isnt($cb1_dest, $inv_topic,  '... not even a small register of it');
ok(!defined($cb1_mesg),      '... so message is undef');
ok(!defined($cb1_xdoc),      '... and XPath is undef');
ok(!defined($cb1_bp),        '... and namespace prefix is undef');


# Message for a matching topic
$r = $sb_consumer->incoming_data(
  _build_frame(
    _mk_notification(
      $valid_topic, $inv_payload,
    )
  )
);
ok(! defined($r), 'Sent Notif with active subscription, matching topic');
is($cb1_pay, $inv_payload,  '... and our active subscription did catch it');
is($cb1_dest, $valid_topic, '... even got the destination right');
is(ref($cb1_mesg),  'XML::LibXML::Element', 'Proper class in message parameter');
is(ref($cb1_xdoc),  'XML::LibXML::XPathContext', 'Proper class in XPath parameter');
ok($cb1_bp,         'SAPO Broker namespace prefix is defined');
ok(length($cb1_bp), '... and has something in it');
is($sb_consumer, $cb1_sb, 'Proper Protocol object in callback also');


# Activate second subscription over same topic
my ($cb2_sb, $cb2_pay, $cb2_dest, $cb2_mesg, $cb2_xdoc, $cb2_bp);
$r = $sb_consumer->subscribe({
  topic => $valid_topic,
  as_queue => 'q1',
  callback => sub {
    ($cb2_sb, $cb2_pay, $cb2_dest, $cb2_mesg, $cb2_xdoc, $cb2_bp) = @_;
    return;
  },
});


# Message for a matching topic (two matches)
($cb1_sb, $cb1_pay, $cb1_dest, $cb1_mesg, $cb1_xdoc, $cb1_bp) =
(undef,   undef,    undef,     undef,     undef,     undef  );

$r = $sb_consumer->incoming_data(
  _build_frame(
    _mk_notification(
      $valid_topic, $inv_payload,
    )
  )
);
ok(! defined($r), 'Sent Notif with active subscription, matching topic');
is($cb2_pay, $inv_payload,  '... and our second active subscription did catch it');
is($cb2_dest, $valid_topic, '... even got the destination right');
is(ref($cb2_mesg),  'XML::LibXML::Element', 'Proper class in message parameter');
is(ref($cb2_xdoc),  'XML::LibXML::XPathContext', 'Proper class in XPath parameter');
ok($cb2_bp,         'SAPO Broker namespace prefix is defined');
ok(length($cb2_bp), '... and has something in it');
is($sb_consumer, $cb2_sb, 'Proper Protocol object in callback also');

is($cb1_pay,  $cb2_pay,  'Callback for subs 1 and subs 2 have same payload');
is($cb1_dest, $cb2_dest, '... and same destination');
is($cb1_mesg, $cb2_mesg, '... and same message element');
is($cb1_xdoc, $cb2_xdoc, '... and same XPath context');
is($cb1_bp,   $cb2_bp,   '... and same Broker namespace prefix');
is($cb1_sb,   $cb2_sb,   '... and even the same Protocol object');


# publish() (wrong API, failures)
ok($sb, "Get ready to test publish() API failures");
throws_ok sub { $sb->publish() },
          qr/Missing required parameter/,
          '... no parameters, dies properly';
throws_ok sub { $sb->publish({}) },
          qr/Missing required parameter/,
          '... empty param hashref, dies properly';
throws_ok sub { $sb->publish({ payload => '' }) },
          qr/Missing required parameter 'topic'/,
          '... missing topic, dies properly';
throws_ok sub { $sb->publish({ topic => '' }) },
          qr/Missing required parameter 'topic'/,
          '... empty topic, dies properly';
throws_ok sub { $sb->publish({ topic => '/test' }) },
          qr/Missing required parameter 'payload'/,
          '... missing payload, dies properly';
TODO: {
  todo_skip('Not implemented yet', 1);
  throws_ok sub { $sb->publish({ topic => '/test', payload => '2321', wtf => 1 }) },
            qr/Parameter unknown 'wtf', /,
            '... unknown parameter, dies properly';
}

# subscribe() (wrong API, failures)
ok($sb, "Get ready to test subscribe() API failures");
throws_ok sub { $sb->subscribe() },
          qr/Missing required parameter/,
          '... no parameters, dies properly';
throws_ok sub { $sb->subscribe({}) },
          qr/Missing required parameter/,
          '... empty param hashref, dies properly';
throws_ok sub { $sb->subscribe({ as_queue => 'q1' }) },
          qr/Missing required parameter 'topic'/,
          '... missing topic, dies properly';
throws_ok sub { $sb->subscribe({ topic => '' }) },
          qr/Missing required parameter 'topic'/,
          '... empty topic, dies properly';
throws_ok sub { $sb->subscribe({ topic => '/test', as_queue => '' }) },
          qr/Missing valid parameter 'as_queue'/,
          '... empty queue name, dies properly';
throws_ok sub { $sb->subscribe({ topic => '/test', callback => '' }) },
          qr/Parameter 'callback' must be a CODE ref, /,
          '... non-CODE-ref callback, dies properly';
TODO: {
  todo_skip('Not implemented yet', 1);
  throws_ok sub { $sb->subscribe({ topic => '/test', payload => '2321' }) },
            qr/Parameter unknown 'payload', /,
            '... unknown parameter, dies properly';
}
        
#######
# Utils

sub _mk_notification {
  my ($topic, $payload) = @_;
  my $msg = <<EOF;
    <soap:Envelope
    	xmlns:soap="http://www.w3.org/2003/05/soap-envelope"
    	xmlns:wsa="http://www.w3.org/2005/08/addressing"
    	xmlns:mq="http://services.sapo.pt/broker">
    	<soap:Header>
    		<wsa:From>
    			<wsa:Address>broker://agent/agent-name/##MYTOPIC##</wsa:Address>
    		</wsa:From>
    		<wsa:Action>http://services.sapo.pt/broker/notification/</wsa:Action>
    		<wsa:MessageID>http://services.sapo.pt/broker/message/ID:1276859168</wsa:MessageID>
    	</soap:Header>
    	<soap:Body>
    		<mq:Notification>
    			<mq:BrokerMessage>
    				<mq:Priority>4</mq:Priority>
    				<mq:MessageId>ID:1276859168</mq:MessageId>
    				<mq:Timestamp/>
    				<mq:Expiration>2007-08-19T09:55:23Z</mq:Expiration>
    				<mq:DestinationName>##MYTOPIC##</mq:DestinationName>
    				<mq:TextPayload>##MYPAYLOAD##</mq:TextPayload>
    			</mq:BrokerMessage>
    		</mq:Notification>
    	</soap:Body>
    </soap:Envelope>
EOF

  $msg =~ s/##MYTOPIC##/$topic/g;
  $msg =~ s/##MYPAYLOAD##/Protocol::SAPO::Broker::_exml($payload)/ge;
  
  return $msg;
}

sub _build_frame {
  my ($msg) = @_;
  
  return pack( 'N', length($msg)).$msg;
}
