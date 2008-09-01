#!perl -T

use strict;
use warnings;
use Test::Most 'no_plan';
use Errno qw( ENOTCONN );
use Protocol::SAPO::Broker;

explain( "Testing Protocol::SAPO::Broker $Protocol::SAPO::Broker::VERSION, Perl $], $^X, PID $$" );

my $conn = 0;
my $msg = '';
my $sb = Protocol::SAPO::Broker->new({
  host => '127.0.0.2',
  port => '2233',
  on_connect   => sub { $_[0]->connected($$) },
  on_send      => sub { $msg = $_[2]         },
});
ok($sb, 'Created a Protocol::SAPO::Broker instance with some paremeters');
is($sb->host,  '127.0.0.2', '... with correct given host');
is($sb->port,  '2233',      '... with correct given port');
is($sb->state, 'connected', '... proper initial state');
is($sb->info,  $$,          '... proper opaque connection info');

# Publish stuff
$msg = undef;
lives_ok sub {
  $sb->publish({
    topic   => '/test',
    payload => 'me',
  })
}, 'Publish ok';
ok($msg, 'Got SOAP a message');
like(
  $msg,
  qr{<b:Publish xmlns:b=["']http://services.sapo.pt/broker["']><b:BrokerMessage},
  '... correct message type',
);
like(
  $msg,
  qr{<b:DestinationName>/test</b:DestinationName},
  '... proper destination'
);
like(
  $msg,
  qr{<b:TextPayload>me</b:TextPayload>},
  '... proper payload'
);


# Publish stuff with ack
$msg = undef;
lives_ok sub {
  $sb->publish({
    topic   => '/test',
    payload => 'me',
    ack     => 1,
  })
}, 'Publish OK';
ok($msg, 'Got SOAP a message');
like(
  $msg,
  qr{<b:Publish b:action-id=["'][\w\d-]+["'] xmlns:b=["']http://services.sapo.pt/broker["']><b:BrokerMessage},
  '... correct message type with ack request',
);
my ($ack_id) = $msg =~ m/b:action-id=["']([\w\d-]+)["']/;
ok($ack_id, "Got a proper ID");

like(
  $msg,
  qr{<b:DestinationName>/test</b:DestinationName},
  '... proper destination'
);
like(
  $msg,
  qr{<b:TextPayload>me</b:TextPayload>},
  '... proper payload'
);


# Send the respective accepted response
lives_ok sub {
  $sb->incoming_data(
    _build_frame(
      _mk_accepted($ack_id)
    )
  )
}, 'The accepted response is processed ok';

lives_ok sub {
  $sb->incoming_data(
    _build_frame(
      _mk_accepted($ack_id)
    )
  )
}, 'A double accepted response is also ok, no harm done';


# Publish stuff - emtpy payload
$msg = undef;
lives_ok sub {
  $sb->publish({
    topic => '/test',
    payload => '',
  })
}, 'Publish called ok';

ok($msg, 'Got SOAP a message');
like(
  $msg,
  qr{<b:Publish xmlns:b=["']http://services.sapo.pt/broker["']><b:BrokerMessage},
  '... correct message type',
);
like(
  $msg,
  qr{<b:DestinationName>/test</b:DestinationName},
  '... proper destination'
);
like(
  $msg,
  qr{<b:TextPayload></b:TextPayload>},
  '... proper payload'
);


# Publish stuff - undef payload
$msg = undef;
lives_ok sub {
  $sb->publish({
    topic => '/test',
    payload => '',
  }) 
}, 'Publish called ok';
ok($msg, 'Got outgoing SOAP message');
like(
  $msg,
  qr{<b:Publish xmlns:b=["']http://services.sapo.pt/broker["']><b:BrokerMessage},
  '... correct message type',
);
like(
  $msg,
  qr{<b:DestinationName>/test</b:DestinationName},
  '... proper destination'
);
like(
  $msg,
  qr{<b:TextPayload></b:TextPayload>},
  '... proper payload'
);


# Now lets fire up a subscriber connection
my ($msg_s, $i_msg_s);
my ($missed_to, $missed_dest, $missed_pay, $xdoc);
my $sb_consumer = Protocol::SAPO::Broker->new({
  host       => '127.0.0.2',
  port       => '2233',
  on_connect => sub { $_[0]->connected($$ % 13) },
  on_send    => sub { $msg_s = $_[2]            },
  on_unmatched_message => sub {
    (undef, $missed_to, $missed_dest, $missed_pay, $xdoc) = @_;
  },
  on_trace_incoming => sub {
    my (undef, $soap) = @_;
    explain("Trace INCOMING: $soap") if $ENV{TEST_SAPO_BROKER_TRACE};
    $i_msg_s = $soap;
  },
  on_trace_outgoing => sub {
    my (undef, $soap) = @_;
    explain("Trace OUTGOING: $soap") if $ENV{TEST_SAPO_BROKER_TRACE};
  },
});
ok($sb_consumer, 'Created a Protocol::SAPO::Broker instance for subscriber');
is($sb_consumer->host,  '127.0.0.2',   '... with correct given host');
is($sb_consumer->port,  '2233',        '... with correct given port');
is($sb_consumer->state, 'connected',   '... proper initial state');
is($sb_consumer->info, $$ % 13,        '... proper connection state');


# Subscribe a topic
lives_ok sub {
  $sb_consumer->subscribe({
    topic      => '/test2',
    on_message => sub {},
  })
}, 'Subscribe ok';
like(
  $msg_s,
  qr{<b:Notify xmlns:b=["']http://services.sapo.pt/broker["']><b:De},
  '... correct message type',
);
like(
  $msg_s,
  qr{<b:DestinationName>/test2</b:DestinationName>},
  '... correct destination /test2',
);
like(
  $msg_s,
  qr{<b:DestinationType>TOPIC</b:DestinationType>},
  '... correct type TOPIC',
);
my $sb_c_subs = $sb_consumer->{subs};
is(ref($sb_c_subs), 'HASH', 'Proper type for subscriptions registry');
is(keys(%$sb_c_subs), 1, '... with the correct number of records');


# Subscribe a topic with ack
my $ack_error;
lives_ok sub {
  $sb_consumer->subscribe({
    topic      => '/test2',
    on_error   => sub { $ack_error = $_[1] },
    on_message => sub {},
  })
}, 'Subscribe ok';
like(
  $msg_s,
  qr{<b:Notify b:action-id=["'][\w\d-]+["'] xmlns:b=["']http://services.sapo.pt/broker["']>},
  '... correct message type',
);
($ack_id) = $msg_s =~ m/b:action-id=["']([\w\d-]+)["']/;
ok($ack_id, 'Got proper ack ID');

like(
  $msg_s,
  qr{<b:DestinationName>/test2</b:DestinationName>},
  '... correct destination /test2',
);
like(
  $msg_s,
  qr{<b:DestinationType>TOPIC</b:DestinationType>},
  '... correct type TOPIC',
);

$ack_error = undef;
lives_ok sub {
  $sb_consumer->incoming_data(
    _build_frame(
      _mk_fault($ack_id)
    )
  )
}, 'Received SOAP fault ok';

ok($ack_error, "On error callback called '$ack_error' '$ack_id'");
is($ack_error, $ack_id, '... with the proper ID');


# Subscribe a topic as queue
lives_ok sub {
  $sb_consumer->subscribe({
    topic    => '/test2',
    as_queue => 'queue3',
    on_message => sub {},
  })
}, 'Subscribe ok';
like(
  $msg_s,
  qr{<b:Notify xmlns:b=["']http://services.sapo.pt/broker["']><b:De},
  '... correct message type',
);
like(
  $msg_s,
  qr{<b:DestinationName>queue3@/test2</b:DestinationName>},
  '... correct destination /test2',
);
like(
  $msg_s,
  qr{<b:DestinationType>TOPIC_AS_QUEUE</b:DestinationType>},
  '... correct type TOPIC_AS_QUEUE',
);


# Subscribe a topic as queue with ack
lives_ok sub {
  $sb_consumer->subscribe({
    topic    => '/test2',
    as_queue => 'queue3',
    ack      => 1,
    on_message => sub {},
  })
}, 'Subscribe ok';
like(
  $msg_s,
  qr{<b:Notify b:action-id=["'][\w\d-]+["'] xmlns:b=["']http://services.sapo.pt/broker["']>},
  '... correct message type',
);
like(
  $msg_s,
  qr{<b:DestinationName>queue3@/test2</b:DestinationName>},
  '... correct destination /test2',
);
like(
  $msg_s,
  qr{<b:DestinationType>TOPIC_AS_QUEUE</b:DestinationType>},
  '... correct type TOPIC_AS_QUEUE',
);


# Message from a unkown subscription
my $inv_to       = 'no_such_rule';
my $inv_topic    = 'no_such_topic';
my $inv_payload  = 'oh my little payload';
my $msg_ukn_subs = _mk_notification($inv_topic, $inv_payload, $inv_to);

$i_msg_s = $missed_pay = $missed_dest = $xdoc = undef;
lives_ok sub {
  $sb_consumer->incoming_data(
    _build_frame($msg_ukn_subs)
  )
}, 'Incoming message, frame ok';
is($i_msg_s,     $msg_ukn_subs, '... proper payload');
is($missed_pay,  $inv_payload,  '... expected payload');
is($missed_dest, $inv_topic,    '... and expected topic');
is($missed_to,   $inv_to,       '... for the proper unmatched destination');
is(
  ref($xdoc) => 'XML::LibXML::XPathContext',
  'Got correct class for XPath doc'
);


# Message from a unkown subscription but expected topic
$msg_ukn_subs = _mk_notification('/test2', $inv_payload, $inv_to);

$i_msg_s = $missed_pay = $missed_dest = $xdoc = undef;
lives_ok sub {
  $sb_consumer->incoming_data(
    _build_frame($msg_ukn_subs)
  )
}, 'Incoming message, frame ok';
is($i_msg_s,     $msg_ukn_subs, '... proper payload');
is($missed_pay,  $inv_payload,  '... expected payload');
is($missed_dest, '/test2',      '... and expected topic');
is($missed_to,   $inv_to,       '... for the proper unmatched destination');
is(
  ref($xdoc) => 'XML::LibXML::XPathContext',
  'Got correct class for XPath doc'
);


# Subscribe with callback, receive notif, check if matched
my $valid_topic = '/real_test';
my ($cb1_sb, $cb1_notif);
lives_ok sub {
  $sb_consumer->subscribe({
    topic      => $valid_topic,
    on_message => sub { ($cb1_sb, $cb1_notif) = @_ }
  })
}, 'Subscribe ok';

$cb1_sb = $cb1_notif = undef;
lives_ok sub {
  $sb_consumer->incoming_data(
    _build_frame(
      _mk_notification(
        $inv_topic, $inv_payload,
      )
    )
  )
}, 'Sent Notif with active subscription, but wrong topic';
ok(!defined($cb1_notif), '... and our active subscription didnt catch it');
ok(!defined($cb1_sb),    '... really didnt catch it');

$cb1_sb = $cb1_notif = undef;
lives_ok sub {
  $sb_consumer->incoming_data(
    _build_frame(
      _mk_notification(
        $valid_topic, $inv_payload, $inv_to,
      )
    )
  )
}, 'Sent Notif with active subscription, correct topic, wrong destination';
ok(!defined($cb1_notif), '... and our active subscription didnt catch it');
ok(!defined($cb1_sb),    '... really didnt catch it');


# Message for a matching topic
$cb1_sb = $cb1_notif = undef;
lives_ok sub {
  $sb_consumer->incoming_data(
    _build_frame(
      _mk_notification(
        $valid_topic, $inv_payload, undef, "$$ $$ $$",
      )
    )
  )
}, 'Sent Notif with active subscription, correct topic/destination';
is($cb1_notif->payload, $inv_payload,  '... and our active subscription did catch it');
is($cb1_notif->topic,   $valid_topic,  '... even got the destination right');
is($cb1_notif->matched, $valid_topic,  '... proper matched entry');
is($cb1_notif->id,      "$$ $$ $$",    '... proper message id');
is($sb_consumer, $cb1_sb, 'Proper Protocol object in callback also');
is(ref($cb1_notif->message),  'XML::LibXML::XPathContext', 'Proper class in XPath parameter');


# Activate second subscription over same topic
my ($cb2_sb, $cb2_notif);
my $cb2_dest = "q1\@$valid_topic";
lives_ok sub {
  $sb_consumer->subscribe({
    topic      => $valid_topic,
    as_queue   => 'q1',
    on_message => sub { ($cb2_sb, $cb2_notif) = @_ },
  })
}, 'Subscribe ok';


# Message for a matching topic (two matches)
$cb1_sb = $cb1_notif = $cb2_sb = $cb2_notif = undef;
lives_ok sub {
  $sb_consumer->incoming_data(
    _build_frame(
      _mk_notification(
        $valid_topic, uc($inv_payload)
      )
    )
  )
}, 'Sent Notifcation with active subscriptions, matching topic';
is($cb1_notif->payload,  uc($inv_payload), '... got the correct payload');
is($cb1_notif->topic,    $valid_topic,     '... and valid topic');
is($cb1_sb, $sb_consumer,                  '... and the same Protocol object');
ok(!defined($cb2_notif), "Didn't match queue-based callback");

$cb1_sb = $cb1_notif = $cb2_sb = $cb2_notif = undef;
lives_ok sub {
  $sb_consumer->incoming_data(
    _build_frame(
      _mk_notification(
        $valid_topic, $inv_payload, $cb2_dest
      )
    )
  )
}, 'Sent Notifcation with active subscriptions, matching topic_as_queue';
is($cb2_notif->topic,   $valid_topic, '... even got the destination right');
is($cb2_notif->payload, $inv_payload, '... and our second active subscription did catch it');
is($cb2_notif->matched, $cb2_dest,    '... matched our topic_as_queue subscription');
is($sb_consumer, $cb2_sb, 'Proper Protocol object in callback also');
ok(!defined($cb1_notif), "Didn't match non-queue callback");


# Test the Acks
$msg = $msg_s = undef;
my $m_id      = $cb2_notif->id;
my $m_matched = $cb2_notif->matched;

lives_ok sub {
  $cb2_notif->ack()
}, 'Sending ack over correct connection';
ok($msg_s,         'Sent over proper connection');
ok(!defined($msg), '... and the other is clean');
like(
  $msg_s,
  qr{<b:Acknowledge\s},
  'It is an Ack message',
);
like(
  $msg_s,
  qr{<b:MessageId>$m_id</b:MessageId>},
  '... proper Id in Ack message',
);
like(
  $msg_s,
  qr{<b:DestinationName>$m_matched</b:DestinationName>},
  '... proper DestinationName in Ack message',
);

$msg = $msg_s = undef;
lives_ok sub {
  $cb2_notif->ack($sb)
}, 'Sending ack over alternate connection';
ok($msg, 'Sent over alternative connection');
ok(!defined($msg_s), '... and the other is clean');
like(
  $msg,
  qr{<b:Acknowledge\s},
  'it is an Ack message',
);
like(
  $msg,
  qr{<b:MessageId>$m_id</b:MessageId>},
  '... proper Id in Ack message',
);
like(
  $msg,
  qr{<b:DestinationName>$m_matched</b:DestinationName>},
  '... proper DestinationName in Ack message',
);


# Publish with on_success callback
my $ack_ok;
lives_ok sub {
  $sb->publish({
    topic      => '/test/with_success_callback',
    payload    => $$,
    on_success => sub { $ack_ok    = $_[1] },
    on_error   => sub { $ack_error = $_[1] },
  })
}, 'Publish with on_success callback ok';
like(
  $msg,
  qr/:action-id=['"].+?['"](\s|>)/,
  "Message with action_id so ack requested",
);
($ack_id) = $msg =~ m/b:action-id=["']([\w\d-]+)["']/;
ok($ack_id, 'Got a proper ID');

$ack_ok = $ack_error = undef;
lives_ok sub {
  $sb->incoming_data(
    _build_frame(
      _mk_accepted($ack_id)
    )
  )
}, 'Received Accepted message ok';
is($ack_ok, $ack_id,     '... with the proper value');
ok(!defined($ack_error), '... and no error reported');

$ack_ok = $ack_error = undef;
lives_ok sub {
  $sb->incoming_data(
    _build_frame(
      _mk_accepted($ack_id)
    )
  ) 
}, 'Second Accepted message received ok';
ok(!defined($ack_ok),    '... as expected success cb not called this time');
ok(!defined($ack_error), '... neither the error cb');


# Publish with on_success callback but receive a fault
lives_ok sub {
  $sb->publish({
    topic      => '/test/with_success_callback',
    payload    => $$,
    on_success => sub { $ack_ok    = $_[1] },
    on_error   => sub { $ack_error = $_[1] },
  })
}, 'Publish with on_success callback ok';
like(
  $msg,
  qr/:action-id=['"].+?['"](\s|>)/,
  "Message with action_id so ack requested",
);
($ack_id) = $msg =~ m/b:action-id=["']([\w\d-]+)["']/;
ok($ack_id, 'Got a good ack ID');

$ack_ok = $ack_error = undef;
lives_ok sub {
  $sb->incoming_data(
    _build_frame(
      _mk_fault($ack_id)
    )
  )
}, 'Received Fault message ok';
is($ack_error, $ack_id, '... with the proper value');
ok(!defined($ack_ok),   '... and no success reported');

$ack_ok = $ack_error = undef;
lives_ok sub {
  $sb->incoming_data(
    _build_frame(
      _mk_fault($ack_id)
    )
  ) 
}, 'Second Fault message received ok';
ok(!defined($ack_ok),    '... as expected error cb not called this time');
ok(!defined($ack_error), '... neither the success cb');


# Publish with on_success callback but receive a fault without ID
lives_ok sub {
  $sb->publish({
    topic      => '/test/with_success_callback',
    payload    => $$,
    on_success => sub { $ack_ok    = $_[1] },
    on_error   => sub { $ack_error = $_[1] },
  })
}, 'Publish with on_success callback ok';
like(
  $msg,
  qr/:action-id=['"].+?['"](\s|>)/,
  "Message with action_id so ack requested",
);
($ack_id) = $msg =~ m/b:action-id=["']([\w\d-]+)["']/;
ok($ack_id, 'Got proper ID');

$ack_ok = $ack_error = undef;
lives_ok sub {
  $sb->incoming_data(
    _build_frame(
      _mk_fault()
    )
  )
}, 'Received Fault message ok';
ok(!defined($ack_error), '... but no ID to match');
ok(!defined($ack_ok),    '... and no success cb either');

$ack_ok = $ack_error = undef;
lives_ok sub {
  $sb->incoming_data(
    _build_frame(
      _mk_accepted($ack_id)
    )
  )
}, 'Received Accepted message ok';
is($ack_ok, $ack_id,     '... with the proper value');
ok(!defined($ack_error), '... and no error reported');


# Subscribe with on_success callback and a real ID
my $my_ack_id = '12314232';
lives_ok sub {
  $sb->publish({
    topic      => '/test/with_success_callback',
    payload    => $$,
    ack_id     => $my_ack_id,
    on_success => sub { $ack_ok    = $_[1] },
    on_error   => sub { $ack_error = $_[1] },
  })
}, 'Publish with on_success callback ok';
like(
  $msg,
  qr/:action-id=['"].+?['"](\s|>)/,
  "Message with action_id so ack requested",
);
($ack_id) = $msg =~ m/b:action-id=["']([\w\d-]+)["']/;
ok($ack_id, 'Got proper ID');

is($ack_id, $my_ack_id, '... with the expected value');
unlike(
  $msg,
  qr/:MessageId>/,
  "Subscribe with ack_id does not generate a MessageId field",
);

$ack_ok = $ack_error = undef;
lives_ok sub {
  $sb->incoming_data(
    _build_frame(
      _mk_accepted($ack_id)
    )
  )
}, 'Received Accepted message ok';
is($ack_ok, $ack_id,     '... with the proper value');
ok(!defined($ack_error), '... and no error reported');


# Test a double consumer to the same topic
my ($notif1, $notif2);
lives_ok sub {
  $sb_consumer->subscribe({
    topic => '/double-take',
    on_message => sub {
      (undef, $notif1) = @_;
    }
  })
}, 'Subscribed first consumer ok';

lives_ok sub {
  $sb_consumer->subscribe({
    topic => '/double-take',
    on_message => sub {
      (undef, $notif2) = @_;
    }
  })
}, 'Subscribed second consumer ok';

lives_ok sub {
  $sb_consumer->incoming_data(
    _build_frame(
      _mk_notification(
        '/double-take', "$$ $$", undef, '1234',
      )
    )
  )
}, 'Received Notification ok';

ok($notif1, 'Got notification on first consumer');
is($notif1->payload, "$$ $$",      '... with proper payload');
is($notif1->topic, '/double-take', '... with correct topic');
is($notif1->id, '1234',            '... and expected id');
ok($notif2, 'Got notification on second consumer');
is($notif2->payload, "$$ $$",      '... with proper payload');
is($notif2->topic, '/double-take', '... with correct topic');
is($notif2->id, '1234',            '... and expected id');
is($notif1, $notif2, 'Actually they are the same notification');


# Reconnect must recover subscriptions

my $b_list_payload;
my $sb_r = Protocol::SAPO::Broker->new({
  on_connect => sub { $_[0]->connected($$ % 13) },
  on_send    => sub { $msg_s = $_[2]            },
  on_state_connected => sub {
    my ($my_sb) = @_;
    
    $my_sb->subscribe({
      topic => 'a-list',
      on_message => sub {},
    });
    $my_sb->subscribe({
      topic => 'b-list',
      on_message => sub { $b_list_payload = $_[1]->payload },
    });
    $my_sb->subscribe({
      topic    => 'a-list',
      as_queue => 'q',
      on_message => sub {},
    });
  },
});

my $subs = $sb_r->{subs};
is(keys(%$subs), 3, 'Three active subscriptions');
lives_ok sub {
  $sb_consumer->incoming_data(undef)
}, "Simulated EOF didn't die";
is($sb_consumer->state, 'connected', '... and reconnect went well');
$subs = $sb_r->{subs};
is(keys(%$subs), 3, 'Got my three active subscriptions back');


#######
# Utils

sub _mk_notification {
  my ($topic, $payload, $wsa_to, $id) = @_;
  $wsa_to ||= '';
  $id ||= 'ID:1276859168';
  
  $wsa_to = "<wsa:To>$wsa_to</wsa:To>" if $wsa_to;
  
  my $msg = <<EOF;
    <soap:Envelope
    	xmlns:soap="http://www.w3.org/2003/05/soap-envelope"
    	xmlns:wsa="http://www.w3.org/2005/08/addressing"
    	xmlns:mq="http://services.sapo.pt/broker">
    	<soap:Header>
    	  $wsa_to
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
    				<mq:MessageId>$id</mq:MessageId>
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

sub _mk_accepted {
  my ($id) = @_;
  
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
    		<mq:Accepted mq:action-id="##MYID##" />
    	</soap:Body>
    </soap:Envelope>
EOF

  $msg =~ s/##MYID##/$id/g if $id;
  
  return $msg;
}

sub _mk_fault {
  my ($id) = @_;

  my $sub_fault = <<SF;
        <soap:Subcode>
          <soap:Value>##MYID##</soap:Value>
        </soap:Subcode>
SF
  $sub_fault = '' unless defined $id;
  
  my $msg = <<"EOF";
    <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:wsa="http://www.w3.org/2005/08/addressing" xmlns:mq="http://services.sapo.pt/broker">
    	<soap:Header/>
    	<soap:Body>
    		<soap:Fault>
    			<soap:Code>
    			  $sub_fault
    				<soap:Value>code is soap:Sender</soap:Value>
    			</soap:Code>
    			<soap:Reason>
    				<soap:Text>text is the error message</soap:Text>
    			</soap:Reason>
    			<soap:Detail>detail is cool</soap:Detail>
    		</soap:Fault>
    	</soap:Body>
    </soap:Envelope>
EOF

  $msg =~ s/##MYID##/$id/g if $id;
  
  return $msg;
}

sub _build_frame {
  my ($msg) = @_;
  
  return pack( 'N', length($msg)).$msg;
}
