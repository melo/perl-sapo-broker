#!perl -T

use Test::More tests => 32;
use Test::Exception;
use Errno qw( ENOTCONN EPIPE );

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
my ($o_msg, $we_err);
$sb = Protocol::SAPO::Broker->new({
  host => '127.0.0.2',
  port => '2233',
  on_connect    => sub { $conn++        },
  on_connected  => sub { $conn += $_[1] },
  on_disconnect => sub { $conn--        },
  on_send       => sub {
    my ($lsb, $m) = @_;
    $o_msg = $m;
    return $sb->write_error(EPIPE);
  },
  on_write_error => sub {
    (undef, $we_err) = @_;
    return;
  }
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

$r = $sb->subscribe({ topic => '/test3' });
ok($r,               'Subscribe failed');
ok($r == EPIPE,      '... returned error is consistent');
ok($sb->error == $r, '... error flag also consistent');
is($sb->state, 'idle', '... state is idle as it should');
ok($we_err,            'Write error callback was called properly');
ok($we_err == $r,      '... and with the proper error and all');
is($conn, 4, 'Disconnected callback called correctly');

# Error connecting
$conn = 0;
$sb = Protocol::SAPO::Broker->new({
  host => '127.0.0.2',
  port => '2233',
  on_connect       => sub { $conn++ },
  on_connect_error => sub { $conn-- },
});

ok($sb, 'Created a Protocol::SAPO::Broker instance with some paremeters');
is($sb->state, 'connecting', '... proper initial state');

is($conn, 1, 'auto-connect called proper callback, still no sucess');

$conn = 0;
$sb->connect_failed(ENOTCONN);
is($conn, -1,              'connect error called proper callback');
is($sb->state, 'idle',     '... and state is up-to-date');
ok($sb->error == ENOTCONN, '... and the error flag is consistent');

