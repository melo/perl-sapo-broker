#!/usr/bin/perl -w

use strict;
use warnings;
use Benchmark qw( timethese cmpthese );
use XML::LibXML;
use XML::LibXML::XPathContext;

my $soap_message = q{
  <soap:Envelope
		xmlns:soap="http://www.w3.org/2003/05/soap-envelope"
		xmlns:wsa="http://www.w3.org/2005/08/addressing"
		xmlns:mq="http://services.sapo.pt/broker">
		<soap:Header>
  		<wsa:To>Sample.*</wsa:To>
			<wsa:From>
				<wsa:Address>broker://agent/agent-name/SampleTopic1</wsa:Address>
			</wsa:From>
			<wsa:Action>http://services.sapo.pt/broker/notification/</wsa:Action>
			<wsa:MessageID>http://services.sapo.pt/broker/message/4e982250-239c-4e25-b177-11774e8090a7</wsa:MessageID>
		</soap:Header>
		<soap:Body>
			<mq:Notification>
				<mq:BrokerMessage>
					<mq:MessageId>4e982250-239c-4e25-b177-11774e8090a7</mq:MessageId> <!-- elemento opcional -->
					<mq:Timestamp>2006-02-21T13:04:49Z</mq:Timestamp> <!-- elemento opcional -->
					<mq:Expiration>2006-02-21T14:44:49Z</mq:Expiration> <!-- elemento opcional -->
					<mq:DestinationName>SampleTopic1</mq:DestinationName>
					<mq:TextPayload>Lorem ipsum dolor sit amet, consectetuer adipiscing elit.</mq:TextPayload>
				</mq:BrokerMessage>
			</mq:Notification>
		</soap:Body>
	</soap:Envelope>
};

my $parser = XML::LibXML->new;

cmpthese(200_000, {
  'libxml' => sub {
    my $xdoc = $parser->parse_string($soap_message);
    $xdoc = XML::LibXML::XPathContext->new($xdoc);
    $xdoc->registerNs( mysoap => 'http://www.w3.org/2003/05/soap-envelope' );
    $xdoc->registerNs( mymq   => 'http://services.sapo.pt/broker'          );
    $xdoc->registerNs( mywsa  => 'http://www.w3.org/2005/08/addressing'    );

    my ($msg) = $xdoc->findnodes('//mysoap:Body/mymq:*');
    my $destination = $xdoc->findvalue('//mymq:DestinationName', $msg);
    my $payload     = $xdoc->findvalue('//mymq:TextPayload', $msg);
    my $to          = $xdoc->findvalue('//mywsa:To');
  },
  
  'regexp' => sub {
    my ($soap) = $soap_message =~ m{xmlns:([^=]+)=(.)http://www.w3.org/2003/05/soap-envelope\2};
    my ($mq)   = $soap_message =~ m{xmlns:([^=]+)=(.)http://services.sapo.pt/broker\2};
    my ($wsa)  = $soap_message =~ m{xmlns:([^=]+)=(.)http://www.w3.org/2005/08/addressing\2};

    my ($msg_type)    = $soap_message =~ m{<${soap}:Body>\s*<${mq}:([a-zA-Z]+)}sm;
    my ($destination) = $soap_message =~ m{<${mq}:DestinationName>([^<]+)</}sm;
    my ($payload)     = $soap_message =~ m{<${mq}:TextPayload>([^<]+)</}sm;
    my ($to)          = $soap_message =~ m{<${wsa}:To>([^<]+)</}sm;
  },
  
  'hard_coded_regexp' => sub {
    my ($msg_type)    = $soap_message =~ m{<soap:Body>\s*<mq:([a-zA-Z]+)}sm;
    my ($destination) = $soap_message =~ m{<mq:DestinationName>([^<]+)</}sm;
    my ($payload)     = $soap_message =~ m{<mq:TextPayload>([^<]+)</}sm;
    my ($to)          = $soap_message =~ m{<wsa:To>([^<]+)</}sm;
  },
  
});


# my ($soap) = $soap_message =~ m{xmlns:([^=]+)=(.)http://www.w3.org/2003/05/soap-envelope\2};
# my ($mq)   = $soap_message =~ m{xmlns:([^=]+)=(.)http://services.sapo.pt/broker\2};
# my ($wsa)  = $soap_message =~ m{xmlns:([^=]+)=(.)http://www.w3.org/2005/08/addressing\2};
# 
# my ($msg_type)    = $soap_message =~ m{<${soap}:Body>\s*<${mq}:([a-zA-Z]+)}sm;
# my ($destination) = $soap_message =~ m{<${mq}:DestinationName>([^<]+)</}sm;
# my ($payload)     = $soap_message =~ m{<${mq}:TextPayload>([^<]+)</}sm;
# my ($to)          = $soap_message =~ m{<${wsa}:To>([^<]+)</}sm;
# print "GOT soap     \t$soap\n";
# print "GOT mq       \t$mq\n";
# print "GOT wsa      \t$wsa\n";
# print "GOT msg_type \t$msg_type\n";
# print "GOT destinat \t$destination\n";
# print "GOT payload  \t$payload\n";
# print "GOT to       \t$to\n";
# 
# ($msg_type)    = $soap_message =~ m{<soap:Body>\s*<mq:([a-zA-Z]+)}sm;
# ($destination) = $soap_message =~ m{<mq:DestinationName>([^<]+)</}sm;
# ($payload)     = $soap_message =~ m{<mq:TextPayload>([^<]+)</}sm;
# ($to)          = $soap_message =~ m{<wsa:To>([^<]+)</}sm;
# print "GOT msg_type \t$msg_type\n";
# print "GOT destinat \t$destination\n";
# print "GOT payload  \t$payload\n";
# print "GOT to       \t$to\n";

