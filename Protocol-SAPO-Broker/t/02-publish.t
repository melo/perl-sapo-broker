#!perl -T

use strict;
use warnings;
use Test::More tests => 19;
use Test::Exception;
use Errno qw( ENOTCONN );

BEGIN {
	use_ok( 'Protocol::SAPO::Broker' );
}

diag( "Testing Protocol::SAPO::Broker $Protocol::SAPO::Broker::VERSION, Perl $], $^X, PID $$" );

my $sb;

my $conn = 0;
my $msg = '';
$sb = Protocol::SAPO::Broker->new({
  host => '127.0.0.2',
  port => '2233',
  auto_connect => 0,
  on_connect => sub { my $lsb = shift; return $lsb->connected($$) },
  on_send    => sub { (undef, undef, $msg) = @_; return },
});
ok($sb, 'Created a Protocol::SAPO::Broker instance with some paremeters');
is($sb->host,  '127.0.0.2',   '... with correct given host');
is($sb->port,  '2233',        '... with correct given port');
is($sb->state, 'idle',        '... proper initial state');

# try publish on non-connected sb
my $r = $sb->publish({ topic => 'test', payload => 'me' });
my $e = $!;
ok($r, 'We get an error back if publish without connected SB');
ok($r == ENOTCONN,     '... proper error, ENOTCONN');
is($e, $r,           '... also set $!');
is($sb->error, $r, '... and $self->error');

# Connect
$sb->connect;
is($sb->state, 'connected',   'Now we are connected');
is($sb->info,  $$,            '... proper opaque info set');

# Publish stuff
$msg = '';
$r = $sb->publish({
  topic => '/test',
  payload => 'me',
});
ok(! defined($r), 'Publish went prety well');
ok($msg =~ m!DestinationName>/test</DestinationName!, '... proper destination');
ok($msg =~ m!<TextPayload>me</TextPayload>!,          '... proper payload');

# TODO: add tests for well formed XML and probably some XPath goodness

# Publish something (wrong API, failures)
throws_ok sub { $sb->publish() },
          qr/Missing required parameter/,
          'no parameters, dies properly';
throws_ok sub { $sb->publish({}) },
          qr/Missing required parameter/,
          'empty param hashref, dies properly';
throws_ok sub { $sb->publish({ payload => '' }) },
          qr/Missing required parameter 'topic'/,
          'missing topic, dies properly';
throws_ok sub { $sb->publish({ topic => '' }) },
          qr/Missing required parameter 'topic'/,
          'empty topic, dies properly';
throws_ok sub { $sb->publish({ topic => '/test' }) },
          qr/Missing required parameter 'payload'/,
          'missing payload, dies properly';
