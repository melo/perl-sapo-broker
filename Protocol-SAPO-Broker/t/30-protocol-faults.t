#!perl -T

use strict;
use warnings;
use Test::More 'no_plan';
use Test::Exception;
use Errno qw( EPROTONOSUPPORT );

BEGIN {
	use_ok( 'Protocol::SAPO::Broker' );
}

diag( "Testing Protocol::SAPO::Broker $Protocol::SAPO::Broker::VERSION, Perl $], $^X, PID $$" );

my ($fault_info, $xdoc, $in_msg, $in_wtf, $in_pay, $error);
my $sb = Protocol::SAPO::Broker->new({
  host => '127.0.0.2',
  port => '2233',
  on_connect => sub {
    my ($lsb) = @_;
    return $lsb->connected($$ % 13);
  },
  on_receive => sub {
    (undef, $in_msg) = @_;
    return;
  },
  on_fault => sub {
    (undef, $fault_info, $xdoc) = @_;
    return;
  },
  on_unknown_payload => sub {
    (undef, $in_wtf, $xdoc) = @_;
    return;
  },
  on_payload_error => sub {
    (undef, $in_pay, $error) = @_;
    return;
  }
});
ok($sb, 'Created a Protocol::SAPO::Broker instance with some paremeters');
is($sb->host,  '127.0.0.2',   '... with correct given host');
is($sb->port,  '2233',        '... with correct given port');
is($sb->state, 'connected',   '... proper initial state');
is($sb->info, $$ % 13,        '... proper connection info');

my $fault = <<EOM;
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:wsa="http://www.w3.org/2005/08/addressing" xmlns:mq="http://services.sapo.pt/broker">
	<soap:Header/>
	<soap:Body>
		<soap:Fault>
			<soap:Code>
				<soap:Value>code is soap:Sender</soap:Value>
			</soap:Code>
			<soap:Reason>
				<soap:Text>text is the error message</soap:Text>
			</soap:Reason>
			<soap:Detail>detail is cool</soap:Detail>
		</soap:Fault>
	</soap:Body>
</soap:Envelope>
EOM

my $r = $sb->incoming_data(_build_frame($fault));
ok(!defined($r), 'We got a frame successfully');
is($in_msg, $fault,       '... the payload is correct');
ok($in_msg =~ m!:Fault>!, '... and it looks like a fault');
ok(ref($xdoc),            '... and it has a valid document object');
is(ref($xdoc), 'XML::LibXML::XPathContext', '... with the proper class');

ok($fault_info, 'We got a SOAP Fault');
is($fault_info->{code},   'code is soap:Sender',       '... code is correct');
is($fault_info->{reason}, 'text is the error message', '... reason is correct');
is($fault_info->{detail}, 'detail is cool',            '... detail is correct');


my $wtf = <<EOM;
<soap:Envelope
	xmlns:soap="http://www.w3.org/2003/05/soap-envelope"
	xmlns:wsa="http://www.w3.org/2005/08/addressing"
	xmlns:mq="NO-FREACKING-KNOWN-PROTOCOL">
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

$r = $sb->incoming_data(_build_frame($wtf));
ok(!defined($r), 'We got a frame successfully for an unkown protocol');
is($in_msg, $wtf, '... the payload is correct');
ok(ref($xdoc),    '... and it has a valid document object');
is(ref($xdoc), 'XML::LibXML::XPathContext', '... with the proper class');

ok($in_wtf, 'We got a unkonwn protocol frame');
is($in_wtf, $in_msg, '... and it was the correct payload');


# totally invalid XML
my $bad_xml = 'no valid xml in here';
$r = $sb->incoming_data(_build_frame($bad_xml));
ok(!defined($r), 'We got a frame sucessfull');
ok($sb->error == EPROTONOSUPPORT, '... consistent error flag');
is($in_msg, $bad_xml,             '... the payload is correct');
is(
  $in_pay, $bad_xml,
  '... and the bad payload is the expected one',
);
ok(
  $error =~ m!parser error : Start tag expected!,
  '... and the expected invalid XML error',
);


sub _build_frame {
  my ($msg) = @_;
  
  return pack( 'N', length($msg)).$msg;
}
