#!perl -T

use Test::More tests => 8;

BEGIN {
	use_ok( 'Net::SAPO::Broker' );
}

diag( "Testing Net::SAPO::Broker $Net::SAPO::Broker::VERSION, Perl $], $^X" );

SKIP: {
  skip(
    'Net::SAPO::Broker tests require a TEST_SAPO_BROKER ENV with the IP of agent to use',
    7,
  ) unless $ENV{TEST_SAPO_BROKER};
  
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


  my $sb = Net::SAPO::Broker->new;
  ok($sb);
  is($sb->state, 'connected', 'Good connection now');

  my $r = $sb->publish({
    topic   => '/test/foo',
    payload => 'hello world',
  });
  ok(!defined($r), 'Publish succeeded');
}
