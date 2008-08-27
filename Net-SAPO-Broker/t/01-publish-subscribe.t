#!perl -T

use strict;
use warnings;
use Test::More;
use LWP::UserAgent;
use Net::SAPO::Broker;

END { _cleanup_all_queues() }

if ($ENV{TEST_SAPO_BROKER}) {
  plan tests => 52;
}
else {
  plan 'skip_all',
    'Set TEST_SAPO_BROKER ENV with the IP of agent to use for tests';
}

diag( "Testing Net::SAPO::Broker $Net::SAPO::Broker::VERSION, Perl $], $^X" );
_cleanup_all_queues();


my $sb = Net::SAPO::Broker->new({
  auto_connect => 0,
});
ok($sb);
is($sb->state, 'idle', 'Idle, not connected');

my $r = $sb->publish({
  topic   => '/test/foo',
  payload => 'hello world',
});
ok($r, "Publish without a connection will fail: $r");

$sb->connect;
is($sb->state, 'connected', 'User started connection ok');

my ($ukn_payload, $ukn_message);
$sb = Net::SAPO::Broker->new({
  on_unknown_payload => sub {
    (undef, $ukn_payload) = @_;
  },
  on_unknown_message => sub {
    (undef, $ukn_message) = @_;
  },
  on_trace_incoming => sub {
    my (undef, $soap) = @_;
    diag("Trace INCOMING: $soap") if $ENV{TEST_SAPO_BROKER_TRACE};
  },
  on_trace_outgoing => sub {
    my (undef, $soap) = @_;
    diag("Trace OUTGOING: $soap") if $ENV{TEST_SAPO_BROKER_TRACE};
  },
});
ok($sb, 'Seccond connection ok');
is($sb->state, 'connected', 'Good connection now');

$r = $sb->publish({
  topic   => '/test/foo',
  payload => 'hello world',
});
ok(!defined($r), 'Publish succeeded');

# Check for messsages from the publish() method
$ukn_message = $ukn_payload = undef;
$sb->deliver_messages(1);
ok(!defined($ukn_message), 'No unknown messages after publish');
ok(!defined($ukn_payload), '... nor unknown payloads');

# Start a subscriber
my $unmatched_c;
my $ukn_payload_c;
my $ukn_message_c;
my $sbc = Net::SAPO::Broker->new({
  on_unmatched_message => sub {
    (undef, $unmatched_c) = @_;
    return;
  },
  on_unknown_payload => sub {
    (undef, $ukn_payload_c) = @_;
  },
  on_unknown_message => sub {
    (undef, $ukn_message_c) = @_;
  },
  on_trace_incoming => sub {
    my (undef, $soap) = @_;
    diag("Trace INCOMING: $soap") if $ENV{TEST_SAPO_BROKER_TRACE};
  },
  on_trace_outgoing => sub {
    my (undef, $soap) = @_;
    diag("Trace OUTGOING: $soap") if $ENV{TEST_SAPO_BROKER_TRACE};
  },
});  
ok($sbc, 'Consumer connection ok');
is($sbc->state, 'connected', 'Good connection now');

my $recv_mesg;
$r = $sbc->subscribe({
  topic      => '/test/foo',
  on_message => sub { (undef, $recv_mesg) = @_ },
});
ok(!defined($r), 'Subscribe succeeded');

$unmatched_c = $ukn_message_c = $ukn_payload_c = undef;
$sbc->deliver_messages(1);
ok(!defined($unmatched_c),   'No unmatched messages yet');
ok(!defined($ukn_message_c), '... nor unknown messages');
ok(!defined($ukn_payload_c), '... nor unknown payloads');
  
# Publish something
$sb->publish({
  topic   => '/test/foo',
  payload => $$, # PID
});

# Check for messsages from the publish() method
$ukn_message = $ukn_payload = undef;
$sb->deliver_messages(1);
ok(!defined($ukn_message), 'No unknown messages after publish');
ok(!defined($ukn_payload), '... nor unknown payloads');

# Waits for messages and delivers it
# It will wait at most 1 seconds
$sbc->deliver_messages(1);
ok($recv_mesg, "Got a message and it was matched");
is($recv_mesg->payload, $$,  '... and it has the proper payload');
ok(!defined($unmatched_c),   '... and we didnt receive unmatched messages');
ok(!defined($ukn_payload_c), '... nor any unimplemented payloads');
ok(!defined($ukn_message_c), '... nor any unimplemented messages');

# Subscribe without callback
$r = $sbc->subscribe({
  topic    => '/test/bar',
});
ok(!defined($r), 'Subscribe succeeded');
sleep(1); # Prevent race condition, see tests below

# Clear subscriber status
$recv_mesg = $unmatched_c = $ukn_message_c = $ukn_payload_c = undef;

# Publish something on bar 
$sb->publish({
  topic   => '/test/bar',
  payload => $$, # PID
});

# Check for messsages from the publish() method
$ukn_message = $ukn_payload = undef;
$sb->deliver_messages(1);
ok(!defined($ukn_message), 'No unknown messages after publish');
ok(!defined($ukn_payload), '... nor unknown payloads');

# Waits for messages and delivers it
# It will wait at most 1 seconds
$sbc->deliver_messages(1);
ok($unmatched_c, "Got a match caugth by the general handler");
is($unmatched_c, $$, '... and it has the proper payload');
ok(!defined($recv_mesg), '... and we didnt receive matched messages');
ok(!defined($ukn_payload_c), 'No unimplemented messages');

# Clear status
$recv_mesg = $unmatched_c = undef;

# Publish something on bar 
$sb->publish({
  topic   => '/test/foo',
  payload => $$, # PID
});

$sb->publish({
  topic   => '/test/bar',
  payload => $$, # PID
});

# Check for messsages from the publish() method
$ukn_message = $ukn_payload = undef;
$sb->deliver_messages(1);
ok(!defined($ukn_message), 'No unknown messages after publish');
ok(!defined($ukn_payload), '... nor unknown payloads');

# Waits for messages and delivers it
# It will wait at most 1 seconds
$sbc->deliver_messages(1);
ok($unmatched_c, "Got a match caugth by the general handler");
is($unmatched_c, $$, '... and it has the proper payload');
ok($recv_mesg, "Got a match caugth by the specific handler");
is($recv_mesg->payload, $$,  '... and it has the proper payload');
ok(!defined($ukn_payload_c), 'No unimplemented messages');

# Clear status
$recv_mesg = $ukn_message = undef;

# Publish something on foo and bar with ack's on
$sb->publish({
  topic   => '/test/foo',
  payload => $$, # PID
  ack     => 1,
});

my $suc_id;
my $my_id = 'my_pub_id_1';
$sb->publish({
  topic   => '/test/bar',
  payload => $$, # PID
  id => $my_id,
  on_success => sub {
    (undef, $suc_id) = @_;
  },
});

# Check for messsages from the publish() method, we should receive acks
$ukn_message = $ukn_payload = $suc_id = undef;
$sb->deliver_messages(1);
ok(!defined($ukn_message), 'No unknown messages after publish');
ok(!defined($ukn_payload), '... nor unknown payloads');

ok($suc_id, 'Proper sucess message called');
is($suc_id, $my_id, '... with the correct topic'); 

# Waits for messages and delivers it
# It will wait at most 1 seconds
$sbc->deliver_messages(1);
ok($unmatched_c, "Got a match caugth by the general handler");
is($unmatched_c, $$, '... and it has the proper payload');
ok($recv_mesg, "Got a match caugth by the specific handler");
is($recv_mesg->payload, $$, '... and it has the proper payload');
ok(!defined($ukn_payload_c), 'No unimplemented messages');

# Test race condition does not occour with ack's
TODO: {
  todo_skip('wait_for_confirmation not implemented yet', 1);
  
  $sbc->subscribe({
    topic    => '/test/ypto',
    as_queue => 'q',
    wait_for_confirmation => 1,
    on_message => sub { (undef, $recv_mesg) = @_ },
  });
  $sb->publish({
    topic => '/test/xpto',
    payload => $$,
  });

  $recv_mesg = undef;
  $sbc->deliver_messages(1);
  ok(defined($recv_mesg), 'Quick subscribe with confirmation + publish: no missed messages');
}

# Test TOPIC_AS_QUEUE deliverires
$sbc->subscribe({
  topic      => '/test/taq',
  as_queue   => 'taq1',
  on_message => sub {
    (undef, $recv_mesg) = @_;
  },
  ack_id => 'omfg!',
  on_success => sub {
    (undef, $suc_id) = @_;
  },
});
$suc_id = undef;
$sbc->deliver_messages(1);
ok($suc_id, 'Got a success message to our subscribe');
is($suc_id, 'omfg!', '... with the expected ID');

$sb->publish({
  topic   => '/test/taq',
  payload => "$$ $$",
});

$recv_mesg = undef;
$sbc->deliver_messages(1);
ok($recv_mesg, 'Subscriber as queue got 1 message');
is($recv_mesg->payload, "$$ $$",          '... with proper payload');
is($recv_mesg->topic,   '/test/taq',      '... and with proper topic');
is($recv_mesg->matched, 'taq1@/test/taq', '... and with proper topic');


# Hack, no protocol support yet :((
sub _remove_queue {
  my ($queue) = @_;
  
  my $ua = LWP::UserAgent->new;
  $ua->timeout(30);
  
  my $url = "http://$ENV{TEST_SAPO_BROKER}:3380/broker/admin";
  $ua->post($url, Content => "QUEUE:$queue");
}

sub _cleanup_all_queues {
  _remove_queue('q@/test/ypto');
  _remove_queue('q@/test/xpto');
  _remove_queue('taq1@/test/taq');
}

