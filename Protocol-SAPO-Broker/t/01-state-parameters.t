#!perl -T

use Test::Most 'no_plan';
use Errno qw( ENOTCONN EPIPE ECONNRESET );
use Protocol::SAPO::Broker;

explain( "Testing Protocol::SAPO::Broker $Protocol::SAPO::Broker::VERSION, Perl $], $^X" );

# Test basic auto_connect and auto_reconnect
my $sb = Protocol::SAPO::Broker->new({
  auto_connect => 0,
  on_connect   => sub { $_[0]->connected($$) },
  on_send      => sub {}
});
ok($sb, 'Created a Protocol::SAPO::Broker instance');
is($sb->host, '127.0.0.1', '... proper default host');
is($sb->port, '3322',      '... proper default port');
is($sb->state, 'idle',     '... proper initial state');

$sb = Protocol::SAPO::Broker->new({
  on_connect   => sub { $_[0]->connected($$) },
  on_send      => sub {}
});
ok($sb, 'Created a Protocol::SAPO::Broker instance with auto connect');
is($sb->state, 'connected',     '... proper initial state');

lives_ok sub { $sb->disconnect }, 'Disconnected call ok';
is(
  $sb->state, 'idle',
  '... and idle, auto_reconnect not used on explicit disconnect'
);


# Step by step auto_connect
my $conn = 0;
$sb = Protocol::SAPO::Broker->new({
  host => '127.0.0.2',
  port => '2233',
  on_connect => sub { $conn++ },
  on_send    => sub {},
});
ok($sb, 'Created a Protocol::SAPO::Broker instance with some paremeters');
is($sb->host, '127.0.0.2',   '... with correct given host');
is($sb->port, '2233',        '... with correct given port');
is($sb->state, 'connecting', '... proper initial state');

is($conn, 1, 'auto-connect called proper callback');

lives_ok sub { $sb->connected($$) }, 'Connected call ok';
is($sb->state, 'connected', '... and state moved up to connected');
is($sb->info,  $$,          '... with a proper connection info');

lives_ok sub { $sb->disconnect }, 'Disconnected call ok';
is(
  $sb->state, 'idle',
  '... and idle, auto_reconnect not used on explicit disconnect'
);


# Test write errors
$conn = 0;
my ($o_msg, $we_err);
$sb = Protocol::SAPO::Broker->new({
  auto_reconnect       => 0,
  on_connect           => sub { $conn++    },
  on_state_connected   => sub { $conn *= 2 },
  on_disconnect        => sub { $conn--    },
  on_state_write_error => sub { $we_err = $_[0]->error },
  on_send => sub { $o_msg = $_->[1]; $_[0]->write_error(EPIPE) },
});
ok($sb, 'Created a Protocol::SAPO::Broker instance with some paremeters');
is($sb->state, 'connecting', '... proper initial state');
is($conn, 1, 'auto-connect called proper callback, still no sucess');

$conn = 3;
$sb->connected($$);
is($conn, 6,                'connect success called proper callback');
is($sb->state, 'connected', '... and state is up-to-date');
is($sb->info,  $$, '... and the connected information is consistent');

dies_ok sub {
  $sb->subscribe({ topic => '/test3' })
}, 'Subscribe failed';
is($sb->error, EPIPE,  '... error flag is the expected');
is($sb->state, 'idle', '... state is idle as it should');
ok($we_err,            'Write error callback was called properly');
is($we_err, EPIPE,     '... and with the proper error and all');
is($conn, 5,           'Disconnected callback called correctly');


ok($sb->error, 'We have an error');
$sb->clear_error;
ok(!defined($sb->error), 'Clear error, clears the error, really');


# Error connecting
$conn = 0;
$sb = Protocol::SAPO::Broker->new({
  auto_reconnect         => 0,
  on_connect             => sub { $conn += 1 },
  on_state_connect_error => sub { $conn -= 2 },
  on_send                => sub {},
});
ok($sb, 'Created a Protocol::SAPO::Broker instance with some paremeters');
is($sb->state, 'connecting', '... proper initial state');
is($conn, 1, 'auto-connect called proper callback, still no sucess');

$conn = 0;
$sb->connect_failed(ENOTCONN);
is($conn, -2,            'connect error called proper callback');
is($sb->state, 'idle',   '... and state is up-to-date');
is($sb->error, ENOTCONN, '... and the error flag is consistent');


# Errors reading
$conn = 0;
my ($read_error);
$sb = Protocol::SAPO::Broker->new({
  auto_reconnect      => 0,
  on_connect          => sub { $conn++; $_[0]->connected($$)   },
  on_state_read_error => sub { $read_error = $_[0]->error; $conn = -2 },
  on_send             => sub {},
});
ok($sb, 'Created a Protocol::SAPO::Broker instance with some paremeters');
is($sb->state, 'connected', '... proper initial state');
is($conn, 1,                '... proper callback called');

$conn = 0;
throws_ok
  sub { $sb->read_error(ECONNRESET) },
  qr/Read error: /,
  '';
is($conn, -2,               'read error called proper callback');
is($sb->state, 'idle',      '... and state is up-to-date');
is($sb->error, ECONNRESET,  '... and the error flag is consistent');
is($sb->error, $read_error, '... with the callback argument also');


# EOF
$conn = 0;
my ($eof);
$sb = Protocol::SAPO::Broker->new({
  auto_reconnect => 0,
  on_connect   => sub { $conn++; $_[0]->connected($$)  },
  on_state_eof => sub { $eof++                         },
  on_send      => sub {}
});

ok($sb, 'Created a Protocol::SAPO::Broker instance with some paremeters');
is($sb->state, 'connected', '... proper initial state');
is($conn, 1,                '... proper callback called');

lives_ok sub { $sb->incoming_data(undef) }, 'Incoming data ok';
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
    qr/Missing callback 'on_connect', /,
    'Missing required parameters (callbacks)';


# And now with proper parameters
$r = $sb->init({
  auto_connect => 0,
  on_connect   => sub {},
  on_send      => sub {},
});
ok($r, 'Init a Protocol::SAPO::Broker instance');
is($sb->host, '127.0.0.1', '... proper default host');
is($sb->port, '3322',      '... proper default port');
is($sb->state, 'idle',     '... proper initial state');


# And again with proper parameters
lives_ok {
  $sb = Protocol::SAPO::Broker->new({ skip_init => 1 })
} 'New instance, with skip_init';
lives_ok {
  $sb->init({
    auto_connect => 0,
    on_connect   => sub {},
    on_send      => sub {},
  })
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
    on_send    => sub {},
  })
} 'Inited with auto_connect on';
is($sb->host, '127.0.0.2',   '... proper host');
is($sb->port, '2233',        '... proper port');
is($sb->state, 'connecting', '... proper state');
