#!perl -T

use strict;
use warnings;
use Test::More 'no_plan';
use Test::Exception;
use Errno qw( ENOTCONN );
use Protocol::SAPO::Broker;

diag( "Testing Protocol::SAPO::Broker $Protocol::SAPO::Broker::VERSION, Perl $], $^X, PID $$" );

my ($outgoing_msg, $incoming_msg);
my $sb = Protocol::SAPO::Broker->new({
  on_connect        => sub { $_[0]->connected($$) },
  on_send           => sub { },
  on_trace_outgoing => sub { $outgoing_msg = $_[1] },
  on_trace_incoming => sub { $incoming_msg = $_[1] },
});
ok($sb, 'Valid Protocol::SAPO::Broker');
is($sb->state, 'connected', '... proper initial state');


# Basic enqueue
lives_ok {
  $sb->enqueue({
    queue   => 'queue1',
    payload => $$,
  });
} 'Queue operation successful';

like(
  $outgoing_msg,
  qr/<s:Body><b:Enqueue .+?><b:BrokerMessage>/,
  'Proper Enqueue message generated',
);
like(
  $outgoing_msg,
  qr{<b:DestinationName>queue1</b:DestinationName>},
  '... with a proper DestinatioName',
);
like(
  $outgoing_msg,
  qr{<b:TextPayload>$$</b:TextPayload>},
  '... and the expected TextPayload',
);


# Enqueue to a TOPIC_AS_QUEUE :)
lives_ok {
  $sb->enqueue({
    topic    => 'topic1',
    as_queue => 'queue2',
    payload  => $$,
  });
} 'Queue operation successful';

like(
  $outgoing_msg,
  qr{<b:DestinationName>queue2\@topic1</b:DestinationName>},
  '... with a proper DestinatioName',
);
unlike(
  $outgoing_msg,
  qr{<b:DestinationType>},
  '... but without a DestinationType',
);


# ask for Ack
lives_ok {
  $sb->enqueue({
    queue   => 'queue1',
    payload => $$,
    ack_id  => 'omfg!',
  });
} 'Queue operation successful';

like(
  $outgoing_msg,
  qr/<s:Body><b:Enqueue .*?b:action-id=.omfg!..*?>/,
  'Proper Enqueue message generated with action-id',
);


# ask for Ack with on_success
lives_ok {
  $sb->enqueue({
    queue   => 'queue1',
    payload => $$,
    on_success => sub {},
  });
} 'Queue operation successful';

like(
  $outgoing_msg,
  qr/<s:Body><b:Enqueue .*?b:action-id=.*?>/,
  'Proper Enqueue message generated with action-id via on_success',
);


# ask for Ack with on_error
lives_ok {
  $sb->enqueue({
    queue   => 'queue1',
    payload => $$,
    on_error => sub {},
  });
} 'Queue operation successful';

like(
  $outgoing_msg,
  qr/<s:Body><b:Enqueue .*?b:action-id=.*?>/,
  'Proper Enqueue message generated with action-id via on_error',
);


# Basic poll
ok(!exists $sb->{subs}{queue1}, 'No on_message hooks for queue1');

my $on_message_hook = sub {};
lives_ok {
  $sb->poll({
    queue      => 'queue1',
    on_message => $on_message_hook,
  });
} 'Poll operation successful';

like(
  $outgoing_msg,
  qr/<s:Body><b:Poll .+?>/,
  'Proper Poll message generated',
);
like(
  $outgoing_msg,
  qr{<b:DestinationName>queue1</b:DestinationName>},
  '... with a proper DestinatioName',
);
my $have_subs = exists $sb->{subs}{queue1};
ok($have_subs, 'Now we have on_message hooks for queue1');
SKIP: {
  skip 'Ooops, no subs, lets skip these next few tests', 2 unless $have_subs;
  
  my $subs = $sb->{subs}{queue1};
  is(scalar(@$subs), 1,             '... with a consistent number of hooks');
  is($subs->[-1], $on_message_hook, '... and our own hook is there');
};

# Poll to a TOPIC_AS_QUEUE :)
lives_ok {
  $sb->poll({
    topic    => 'topic1',
    as_queue => 'queue2',
  });
} 'Queue operation successful';

like(
  $outgoing_msg,
  qr{<b:DestinationName>queue2\@topic1</b:DestinationName>},
  '... with a proper DestinatioName',
);
unlike(
  $outgoing_msg,
  qr{<b:DestinationType>},
  '... but without a DestinationType',
);
