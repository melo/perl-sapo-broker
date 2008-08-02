#!perl -T

use strict;
use warnings;
use Test::More 'no_plan';
use Test::Exception;

BEGIN {
	use_ok( 'Protocol::SAPO::Broker' );
}

diag( "Testing Protocol::SAPO::Broker $Protocol::SAPO::Broker::VERSION, Perl $], $^X, PID $$" );

my $i_count = 0;
my $i_msg;
my $sb = Protocol::SAPO::Broker->new({
  host => '127.0.0.2',
  port => '2233',
  on_connect => sub {
    my ($lsb) = @_;
    return $lsb->connected($$ % 13);
  },
  on_message => sub {
    (undef, $i_msg) = @_;
    $i_count++;
    return;
  },
});
ok($sb, 'Created a Protocol::SAPO::Broker instance with some paremeters');
is($sb->host,  '127.0.0.2',   '... with correct given host');
is($sb->port,  '2233',        '... with correct given port');
is($sb->state, 'connected',   '... proper initial state');
is($sb->info, $$ % 13,       '... proper connection info');

my $test_msg = <<EOM;
  <soap:Envelope
  	xmlns:soap="http://www.w3.org/2003/05/soap-envelope"
  	xmlns:wsa="http://www.w3.org/2005/08/addressing"
  	xmlns:mq="http://services.sapo.pt/broker">
  	<soap:Header>
  		<wsa:From>
  			<wsa:Address>broker://agent/agent-name/SampleTopic1</wsa:Address>
  		</wsa:From>
  		<wsa:Action>http://services.sapo.pt/broker/notification/</wsa:Action>
  		<wsa:MessageID>http://services.sapo.pt/broker/message/ID:1276859168</wsa:MessageID>
  	</soap:Header>
  	<soap:Body>
  		<mq:Notification>
  			<mq:BrokerMessage>
  				<mq:Priority>4</mq:Priority>
  				<mq:MessageId>ID:1276859168</mq:MessageId>
  				<mq:Timestamp/>
  				<mq:Expiration>2007-08-19T09:55:23Z</mq:Expiration>
  				<mq:DestinationName>SampleTopic1</mq:DestinationName>
  				<mq:TextPayload>Lorem ipsum dolor sit amet, consectetuer adipiscing elit.</mq:TextPayload>
  			</mq:BrokerMessage>
  		</mq:Notification>
  	</soap:Body>
  </soap:Envelope>
EOM

# Check init state
is($sb->expect, 0,  'Protocol is expecting a frame');
is($sb->buffer, '', '... and the internal protocol is empty');

# Basic test, full frame
my $r = $sb->incoming_data(_build_frame($test_msg));
ok(!defined($r), 'Protocol received network data ok');
is($test_msg, $i_msg, '... incoming message is correct');
is($i_count, 1, '... and it was a single message');

is($sb->expect, 0,  'Again, protocol is expecting a frame');
is($sb->buffer, '', '... and the internal protocol is empty');

# Slice frame in 4, spoon feed
$i_msg = undef;
$i_count = 0;
my $frame = _build_frame($test_msg);
my $sfl = length($frame);
is($sfl, length($test_msg)+4, 'Good frame for spoon feed tests');

$frame = $frame x 4; # actually we will send 4 frames

# ... first slices, very small
foreach my $slice (1..3) {
  $r = $sb->incoming_data(substr($frame, 0, 1, ''));
  ok(!defined($r),     '... received correctly slice $slice');
  ok(!defined($i_msg), '... still no current incoming message');
  is($sb->expect, 0,   '... still expecting length header');
  is($i_count, 0,      '... incoming message count still 0');
}

# send a frame length, so we will be left in the middle of the header again
# but with a message delivered
$r = $sb->incoming_data(substr($frame, 0, $sfl, ''));
ok(!defined($r),      '... received correctly slice 4, frame length');
is($sb->expect, 0,    '... expecting header again');
is($i_count, 1,       'Got one messages through');
ok(defined($i_msg),   '... last incoming message is defined');
is($i_msg, $test_msg, '... and correct');


# send rest minus 1 - this will flush three full frames and keep the
# fourth pending
$r = $sb->incoming_data(substr($frame, 0, length($frame)-1, ''));
ok(!defined($r),   '... received correctly slice 5');
is($sb->expect, 1, '... just 1 byte left');
is(
  $sb->buffer,
  substr($test_msg, 0, length($test_msg)-1),
  '... buffer looks good'
);
is($i_count, 3,       'Got three messages through');
ok(defined($i_msg),   '... last incoming message is defined');
is($i_msg, $test_msg, '... and correct');

$i_msg = undef;

# final slice
$r = $sb->incoming_data($frame);
ok(!defined($r),      '... received correctly slice 5, last');
ok(defined($i_msg),   '... incoming message detected');
is($i_msg, $test_msg, '... and it is correct');
is($i_count, 4,       '... and incoming counter is also correct at 4');

is($sb->expect, 0,  'Again, protocol is expecting a frame');
is($sb->buffer, '', '... and the internal protocol buffer is empty');


sub _build_frame {
  my ($msg) = @_;
  
  return pack( 'N', length($msg)).$msg;
}
