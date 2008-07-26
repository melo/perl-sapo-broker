#!perl -T

use Test::More tests => 19;
use Test::Exception;

BEGIN {
	use_ok( 'Protocol::SAPO::Broker' );
}

diag( "Testing Protocol::SAPO::Broker $Protocol::SAPO::Broker::VERSION, Perl $], $^X" );

my $sb;

throws_ok { $sb = Protocol::SAPO::Broker->new }
          qr/Missing callback 'connect', /,
          'Missing required parameters (callbacks)';

$sb = Protocol::SAPO::Broker->new({ auto_connect => 0 });
ok($sb, 'Created a Protocol::SAPO::Broker instance');
is($sb->host, '127.0.0.1', '... proper default host');
is($sb->port, '3322',      '... proper default port');
is($sb->state, 'idle',     '... proper initial state');

my $conn = 0;
$sb = Protocol::SAPO::Broker->new({
  host => '127.0.0.2',
  port => '2233',
  on_connect => sub { $conn++ },
});
ok($sb, 'Created a Protocol::SAPO::Broker instance with some paremeters');
is($sb->host, '127.0.0.2',   '... with correct given host');
is($sb->port, '2233',        '... with correct given port');
is($sb->state, 'connecting', '... proper initial state');

is($conn, 1, 'auto-connect called proper callback');

$conn = 0;
$sb = Protocol::SAPO::Broker->new({
  host => '127.0.0.2',
  port => '2233',
  on_connect   => sub { $conn++        },
  on_connected => sub { $conn += $_[1] },
});

ok($sb, 'Created a Protocol::SAPO::Broker instance with some paremeters');
is($sb->host, '127.0.0.2',   '... with correct given host');
is($sb->port, '2233',        '... with correct given port');
is($sb->state, 'connecting', '... proper initial state');

is($conn, 1, 'auto-connect called proper callback, still no sucess');

$conn = 0;
$sb->connected(5);
is($conn, 5, 'connect success called proper callback');
is($sb->state, 'connected', '... and state is up-to-date');
is($sb->info, 5, '... and the connected information is consistent');
