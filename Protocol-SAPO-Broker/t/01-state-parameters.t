#!perl -T

use Test::More tests => 9;

BEGIN {
	use_ok( 'Protocol::SAPO::Broker' );
}

diag( "Testing Protocol::SAPO::Broker $Protocol::SAPO::Broker::VERSION, Perl $], $^X" );

my $sb = Protocol::SAPO::Broker->new;
ok($sb, 'Created a Protocol::SAPO::Broker instance');
is($sb->host, '127.0.0.1', '... proper default host');
is($sb->port, '3322',      '... proper default port');
is($sb->state, 'idle',     '... proper initial state');

$sb = Protocol::SAPO::Broker->new({ host => '127.0.0.2', port => '2233' });
ok($sb, 'Created a Protocol::SAPO::Broker instance with some paremeters');
is($sb->host, '127.0.0.2', '... with correct given host');
is($sb->port, '2233',      '... with correct given port');
is($sb->state, 'idle',     '... proper initial state');
