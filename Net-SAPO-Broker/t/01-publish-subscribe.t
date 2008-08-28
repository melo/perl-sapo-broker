#!perl -T

use strict;
use warnings;
use Test::More;
use LWP::UserAgent;
use Net::SAPO::Broker;

END { _cleanup_all_queues() }

if ($ENV{TEST_SAPO_BROKER}) {
  plan 'no_plan';
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
  ack_id => 'omfg!',
  on_success => sub {
    (undef, $suc_id) = @_;
  },
});
$suc_id = undef;
$sb->deliver_messages(1);
ok($suc_id, 'Got a success message to our publish');
is($suc_id, 'omfg!', '... with the expected ID');

$recv_mesg = undef;
$sbc->deliver_messages(1);
ok($recv_mesg, 'Subscriber as queue got 1 message');
is($recv_mesg->payload, "$$ $$",          '... with proper payload');
is($recv_mesg->topic,   '/test/taq',      '... and with proper topic');
is($recv_mesg->matched, 'taq1@/test/taq', '... and with proper topic');

# Test Ack messages             
$ENV{TEST_SAPO_BROKER_TRACE} = 1;
my $ta_topic    = '/test/taq/ack'; 
my $ta_queue_id = "taq-$$"; 
my $ta_queue    = "$ta_queue_id\@$ta_topic";
my $ta_payload  = 'test acks';
my $ta_msg_id   = '123456789';
my $ta_delay    = 10;
my $ta_trace_out;

my $ta_sb_args = {
  on_trace_incoming => sub {
    my (undef, $soap) = @_;
    diag("Trace INCOMING: $soap") if $ENV{TEST_SAPO_BROKER_TRACE};
  },
  on_trace_outgoing => sub {
    my (undef, $soap) = @_;
    diag("Trace OUTGOING: $soap") if $ENV{TEST_SAPO_BROKER_TRACE};
    $ta_trace_out = $soap;
  },
  on_unmatched_message => sub {
    my (undef, $soap, $dest) = @_;
    diag("Trace UNMATCHED to $dest: $soap") if $ENV{TEST_SAPO_BROKER_TRACE};
  },
};

my $sb0 = Net::SAPO::Broker->new($ta_sb_args);
my $sb1 = Net::SAPO::Broker->new($ta_sb_args);
my $sb2 = Net::SAPO::Broker->new($ta_sb_args);
my $sb3 = Net::SAPO::Broker->new($ta_sb_args);
my $sb4 = Net::SAPO::Broker->new($ta_sb_args);
my $sb5 = Net::SAPO::Broker->new($ta_sb_args);
my $sb6 = Net::SAPO::Broker->new($ta_sb_args);

# my $ta_notif1;
# $sb1->subscribe({
#   topic    => $ta_topic,
#   as_queue => $ta_queue_id,
#   ack      => 1,
#   on_message => sub { $ta_notif1 = $_[1] },
# });
# diag("Waiting for OK from subscribe on subscriber 1");
# $sb1->deliver_messages($ta_delay);
# 
# $sb0->publish({
#   topic   => $ta_topic,
#   payload => $ta_payload,
# });
# 
# diag("Waiting for messages on subscriber 1");
# $sb1->deliver_messages($ta_delay);
# ok($ta_notif1, 'Got notification of incoming message on subscriber 1');
# SKIP: {
#   skip "skip test about received message, we didn't get it", 2 unless $ta_notif1;
#   
#   is($ta_notif1->payload, $ta_payload, '... with proper payload');
#   is($ta_notif1->topic,   $ta_topic,   '... and proper topic');
# }
# 
# $sb1->disconnect;
# 
# my $ta_notif2;
# $sb2->subscribe({
#   topic    => $ta_topic,
#   as_queue => $ta_queue_id,
#   on_message => sub { $ta_notif2 = $_[1] },
# });
# 
# diag("Waiting for messages on subscriber 2");
# $sb2->deliver_messages($ta_delay);
# ok($ta_notif2, 'Got notification of incoming message on subscriber 2');
# SKIP: {
#   skip "skip test about received message, we didn't get it", 2 unless $ta_notif2;
#   
#   is($ta_notif2->payload, $ta_payload, '... with proper payload');
#   is($ta_notif2->topic,   $ta_topic,   '... and proper topic');
# }
# 
# $sb2->disconnect;
# 
# my $ta_notif3;
# $sb3->poll({
#   topic    => $ta_topic,
#   as_queue => $ta_queue_id,
#   on_message => sub { $ta_notif3 = $_[1] },
# });
# 
# diag("Waiting for messages on subscriber 3");
# $sb3->deliver_messages($ta_delay);
# ok($ta_notif3, 'Got notification of incoming message on subscriber 3');
# SKIP: {
#   skip "skip test about received message, we didn't get it", 2 unless $ta_notif3;
#   
#   is($ta_notif3->payload, $ta_payload, '... with proper payload');
#   is($ta_notif3->topic,   $ta_topic,   '... and proper topic');
# }
# 
# my $ta_notif4;
# $sb4->poll({
#   topic    => $ta_topic,
#   as_queue => $ta_queue_id,
#   on_message => sub { $ta_notif4 = $_[1] },
# });
# 
# diag("Waiting for messages on subscriber 4");
# $sb4->deliver_messages($ta_delay);
# ok(!$ta_notif4, 'No notification for subscriber 4, sent to 3 instead');
# 
# diag("Subscriber 3 disconnected");
# $sb3->disconnect;
# 
# diag("Waiting again for messages on subscriber 4");
# $sb4->deliver_messages($ta_delay);
# ok(!$ta_notif4, "No notification for subscriber 4, queue didn't notice 3 died");
# 
# my $ta_notif5;
# $sb5->poll({
#   topic    => $ta_topic,
#   as_queue => $ta_queue_id,
#   on_message => sub { $ta_notif5 = $_[1] },
# });
# 
# diag("Waiting for messages on subscriber 5");
# $sb5->deliver_messages($ta_delay);
# ok($ta_notif5, 'New poller, so consumer 5 got it instead of 4');
# SKIP: {
#   skip "skip test about received message, we (5) didn't get it", 5
#     unless $ta_notif5;
#   
#   is($ta_notif5->payload, $ta_payload, '... with proper payload');
#   is($ta_notif5->topic,   $ta_topic,   '... and proper topic');
#   
#   my $id = $ta_notif5->id;
#   $ta_trace_out = undef;
#   $ta_notif5->ack;
#   ok($ta_trace_out, 'Ack sent over consumer 5');
#   like(
#     $ta_trace_out,
#     qr/<b:Acknowledge/,
#     '... proper message',
#   );
#   like(
#     $ta_trace_out,
#     qr{<b:MessageId>$id</b:MessageId},
#     '... with proper id',
#   );
# }
# 
# diag("Waiting again for messages on subscriber 4");
# $sb4->deliver_messages($ta_delay);
# ok(!$ta_notif4, "No notification for subscriber 4, still nothing there");
# 
# my $ta_notif6;
# $sb6->poll({
#   topic    => $ta_topic,
#   as_queue => $ta_queue_id,
#   on_message => sub { $ta_notif6 = $_[1] },
# });
# 
# diag("Waiting for messages on subscriber 6");
# $sb6->deliver_messages($ta_delay);
# ok(!$ta_notif6, 'No notification for subscriber 6, message was acked by 5');




#######
# Utils

# Hack, no protocol support yet :((
sub _remove_queue {
  my ($queue) = @_;
  return unless $ENV{TEST_SAPO_BROKER};
  
  my $ua = LWP::UserAgent->new;
  $ua->timeout(30);
  
  my $url = "http://$ENV{TEST_SAPO_BROKER}:3380/broker/admin";
  $ua->post($url, Content => "QUEUE:$queue");
}

sub _cleanup_all_queues {
  for my $sbc ($sb, $sbc, $sb0, $sb1, $sb2, $sb3, $sb4, $sb5, $sb6) {
    $sbc->disconnect if $sbc;
    
  }
  _remove_queue('q@/test/ypto');
  _remove_queue('q@/test/xpto');
  _remove_queue('taq1@/test/taq');
  _remove_queue($ta_queue) if $ta_queue;
}

