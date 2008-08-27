#!perl -T

use Test::More tests => 64;
use Test::Exception;
use Errno qw( ENOTCONN EPIPE ECONNRESET );

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

# Errors reading
$conn = 0;
my ($read_error);
$sb = Protocol::SAPO::Broker->new({
  host => '127.0.0.2',
  port => '2233',
  on_connect    => sub { my ($lsb) = @_; $conn++; $lsb->connected($$)  },
  on_read_error => sub { (undef, $read_error) = @_; $conn = -2; return },
});

ok($sb, 'Created a Protocol::SAPO::Broker instance with some paremeters');
is($sb->state, 'connected', '... proper initial state');
is($conn, 1,                '... proper callback called');

$conn = 0;
$sb->read_error(ECONNRESET);
is($conn, -2,              'read error called proper callback');
is($sb->state, 'idle',        '... and state is up-to-date');
ok($sb->error == ECONNRESET,  '... and the error flag is consistent');
ok($sb->error == $read_error, '... with the callback argument also');

# EOF
$conn = 0;
my ($eof);
$sb = Protocol::SAPO::Broker->new({
  host => '127.0.0.2',
  port => '2233',
  on_connect => sub { my ($lsb) = @_; $conn++; $lsb->connected($$)  },
  on_eof     => sub { $eof++; return },
});

ok($sb, 'Created a Protocol::SAPO::Broker instance with some paremeters');
is($sb->state, 'connected', '... proper initial state');
is($conn, 1,                '... proper callback called');

$sb->incoming_data(undef);
ok($eof,                 'read error called proper callback');
is($sb->state, 'idle',   '... and state is up-to-date');
ok(!defined($sb->error), '... and the error flag is cleared');

# Test the new()/init() split
lives_ok {
  $sb = Protocol::SAPO::Broker->new({
    skip_init => 1,
    host => '1.1.1.1',
    port => '4444',
  })
} 'We can create a instance without problems using skip_init';

ok(!defined($sb->host),  '... host will be undefined');
ok(!defined($sb->port),  '... port will be undefined');
ok(!defined($sb->state), '... and state will be undefined');

# Now init but with missing parameters
throws_ok { $sb->init }
    qr/Missing callback 'connect', /,
    'Missing required parameters (callbacks)';

# And now with proper parameters
$r = $sb->init({ auto_connect => 0 });
ok($r, 'Init a Protocol::SAPO::Broker instance');
is($sb->host, '127.0.0.1', '... proper default host');
is($sb->port, '3322',      '... proper default port');
is($sb->state, 'idle',     '... proper initial state');

# And now with proper parameters
lives_ok {
  $sb = Protocol::SAPO::Broker->new({ skip_init => 1 })
} 'New instance, with skip_init';
lives_ok {
  $r = $sb->init({ auto_connect => 0 });
} 'No problems init without connect';
is($sb->host, '127.0.0.1', '... proper default host');
is($sb->port, '3322',      '... proper default port');
is($sb->state, 'idle',     '... proper initial state');

# And now with proper parameters
lives_ok {
  $sb = Protocol::SAPO::Broker->new({ skip_init => 1 })
} 'New instance, with skip_init';
lives_ok {
  $r = $sb->init({
    host => '127.0.0.2',
    port => '2233',
    on_connect => sub { $conn++ },
  })
} 'Inited with auto_connect on';
is($sb->host, '127.0.0.2',   '... proper host');
is($sb->port, '2233',        '... proper port');
is($sb->state, 'connecting', '... proper state');

