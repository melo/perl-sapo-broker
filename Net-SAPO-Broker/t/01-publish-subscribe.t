#!perl -T

use strict;
use warnings;
use Test::More tests => 47;

BEGIN {
	use_ok( 'Net::SAPO::Broker' );
}

diag( "Testing Net::SAPO::Broker $Net::SAPO::Broker::VERSION, Perl $], $^X" );

SKIP: {
  skip(
    'Net::SAPO::Broker tests require a TEST_SAPO_BROKER ENV with the IP of agent to use',
    30,
  ) unless $ENV{TEST_SAPO_BROKER};
  
  my ($ukn_payload, $ukn_message);
  my $sb = Net::SAPO::Broker->new({
    auto_connect => 0,
    on_unknown_payload => sub {
      my (undef, $ukn_payload) = @_;
    },
    on_unknown_message => sub {
      my (undef, $ukn_message) = @_;
    }
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


  $sb = Net::SAPO::Broker->new;
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
      my (undef, $ukn_payload_c) = @_;
    },
    on_unknown_message => sub {
      my (undef, $ukn_message_c) = @_;
    },
  });  
  ok($sbc, 'Consumer connection ok');
  is($sbc->state, 'connected', 'Good connection now');

  my $recv_mesg;
  $r = $sbc->subscribe({
    topic    => '/test/foo',
    callback => sub { (undef, $recv_mesg) = @_ },
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
  is($recv_mesg, $$, '... and it has the proper payload');
  ok(!defined($unmatched_c), '... and we didnt receive unmatched messages');
  ok(!defined($ukn_payload_c), '... nor any unimplemented payloads');
  ok(!defined($ukn_message_c), '... nor any unimplemented messages');

  # Subscribe without callback
  $r = $sbc->subscribe({
    topic    => '/test/bar',
  });
  ok(!defined($r), 'Subscribe succeeded');
  
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
  is($recv_mesg, $$, '... and it has the proper payload');
  ok(!defined($ukn_payload_c), 'No unimplemented messages');
  
  # Clear status
  $recv_mesg = $ukn_message = undef;

  # Publish something on foo and bar with ack's on
  $sb->publish({
    topic   => '/test/foo',
    payload => $$, # PID
    ack     => 1,
  });

  my ($suc_topic, $suc_payload);
  $sb->publish({
    topic   => '/test/bar',
    payload => $$, # PID
    on_success => sub {
      my (undef, $suc_topic, $suc_payload) = @_;
    },
  });

  # Check for messsages from the publish() method, we should receive acks
  $ukn_message = $ukn_payload = undef;
  $sb->deliver_messages(1);
  ok(!defined($ukn_message), 'No unknown messages after publish');
  ok(!defined($ukn_payload), '... nor unknown payloads');
    
  ok($suc_topic, 'Proper sucess message called');
  is($suc_topic,   '/test/foo', '... with the correct topic'); 
  is($suc_payload, $$,          '... and the correct payload');   
  
  # Waits for messages and delivers it
  # It will wait at most 1 seconds
  $sbc->deliver_messages(1);
  ok($unmatched_c, "Got a match caugth by the general handler");
  is($unmatched_c, $$, '... and it has the proper payload');
  ok($recv_mesg, "Got a match caugth by the specific handler");
  is($recv_mesg, $$, '... and it has the proper payload');
  ok(!defined($ukn_payload_c), 'No unimplemented messages');  
}
