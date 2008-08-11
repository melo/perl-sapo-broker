#!perl -T

use strict;
use warnings;
use Test::More tests => 31;

BEGIN {
	use_ok( 'Net::SAPO::Broker' );
}

diag( "Testing Net::SAPO::Broker $Net::SAPO::Broker::VERSION, Perl $], $^X" );

SKIP: {
  skip(
    'Net::SAPO::Broker tests require a TEST_SAPO_BROKER ENV with the IP of agent to use',
    7,
  ) unless $ENV{TEST_SAPO_BROKER};
  
  my $ukn_payload;
  my $sb = Net::SAPO::Broker->new({
    auto_connect => 0,
    on_unknown_payload => sub {
      my (undef, $ukn_payload) = @_;
    },
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

  # Start a subscriber
  my $unmatched;
  my $ukn_payload_c;
  my $sbc = Net::SAPO::Broker->new({
    on_unmatched_message => sub {
      (undef, $unmatched) = @_;
      return;
    },
    on_unknown_payload => sub {
      my (undef, $ukn_payload_c) = @_;
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
  sleep(1);
  
  # Publish something
  $sb->publish({
    topic   => '/test/foo',
    payload => $$, # PID
  });

  # Waits for messages and delivers it
  # It will wait at most 1 seconds
  $sbc->deliver_messages(1);
  ok($recv_mesg, "Got a message and it was matched");
  is($recv_mesg, $$, '... and it has the proper payload');
  ok(!defined($unmatched), '... and we didnt receive unmatched messages');
  ok(!defined($ukn_payload_c), '... nor any unimplemented ones');

  # Subscribe without callback
  $r = $sbc->subscribe({
    topic    => '/test/bar',
  });
  ok(!defined($r), 'Subscribe succeeded');
  sleep(1);
  
  # Clear status
  $recv_mesg = $unmatched = undef;
  
  # Publish something on bar 
  $sb->publish({
    topic   => '/test/bar',
    payload => $$, # PID
  });

  # Waits for messages and delivers it
  # It will wait at most 1 seconds
  $sbc->deliver_messages(1);
  ok($unmatched, "Got a match caugth by the general handler");
  is($unmatched, $$, '... and it has the proper payload');
  ok(!defined($recv_mesg), '... and we didnt receive matched messages');
  ok(!defined($ukn_payload_c), 'No unimplemented messages');

  # Clear status
  $recv_mesg = $unmatched = undef;
  
  # Publish something on bar 
  $sb->publish({
    topic   => '/test/foo',
    payload => $$, # PID
  });

  $sb->publish({
    topic   => '/test/bar',
    payload => $$, # PID
  });
  
  # Waits for messages and delivers it
  # It will wait at most 1 seconds
  $sbc->deliver_messages(1);
  ok($unmatched, "Got a match caugth by the general handler");
  is($unmatched, $$, '... and it has the proper payload');
  ok($recv_mesg, "Got a match caugth by the specific handler");
  is($recv_mesg, $$, '... and it has the proper payload');
  ok(!defined($ukn_payload_c), 'No unimplemented messages');
  
  # Clear status
  $recv_mesg = $unmatched = undef;
  
  # Publish something on foo and bar with ack's on
  $sb->publish({
    topic   => '/test/foo',
    payload => $$, # PID
    ack     => 1,
  });

  $sb->publish({
    topic   => '/test/bar',
    payload => $$, # PID
    ack     => 1,
  });
  
  # Waits for the acks
  $sb->deliver_messages(1);
  ok(!defined($ukn_payload), 'Wait for acks, no unimplemented messages');
  
  # Waits for messages and delivers it
  # It will wait at most 1 seconds
  $sbc->deliver_messages(1);
  ok($unmatched, "Got a match caugth by the general handler");
  is($unmatched, $$, '... and it has the proper payload');
  ok($recv_mesg, "Got a match caugth by the specific handler");
  is($recv_mesg, $$, '... and it has the proper payload');
  ok(!defined($ukn_payload_c), 'No unimplemented messages');
  
}
