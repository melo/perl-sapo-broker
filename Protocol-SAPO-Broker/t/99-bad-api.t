#!perl -T

use strict;
use warnings;
use Test::More tests => 13;
use Test::Exception;
use Protocol::SAPO::Broker;

my $sb = Protocol::SAPO::Broker->new({
  on_connect => sub { $_[0]->connected },
});

# publish() (wrong API, failures)
diag("Testing publish() API failures");
throws_ok sub { $sb->publish() },
          qr/Missing required parameter/,
          '... no parameters, dies properly';
throws_ok sub { $sb->publish({}) },
          qr/Missing required parameter/,
          '... empty param hashref, dies properly';
throws_ok sub { $sb->publish({ payload => '' }) },
          qr/Missing required parameter 'topic'/,
          '... missing topic, dies properly';
throws_ok sub { $sb->publish({ topic => '' }) },
          qr/Missing required parameter 'topic'/,
          '... empty topic, dies properly';
throws_ok sub { $sb->publish({ topic => '/test' }) },
          qr/Missing required parameter 'payload'/,
          '... missing payload, dies properly';
TODO: {
  todo_skip('Not implemented yet', 1);
  throws_ok sub { $sb->publish({ topic => '/test', payload => '2321', wtf => 1 }) },
            qr/Parameter unknown 'wtf', /,
            '... unknown parameter, dies properly';
}


# subscribe() (wrong API, failures)
diag("Testing subscribe() API failures");
throws_ok sub { $sb->subscribe() },
          qr/Missing required parameter/,
          '... no parameters, dies properly';
throws_ok sub { $sb->subscribe({}) },
          qr/Missing required parameter/,
          '... empty param hashref, dies properly';
throws_ok sub { $sb->subscribe({ as_queue => 'q1' }) },
          qr/Missing required parameter 'topic'/,
          '... missing topic, dies properly';
throws_ok sub { $sb->subscribe({ topic => '' }) },
          qr/Missing required parameter 'topic'/,
          '... empty topic, dies properly';
throws_ok sub { $sb->subscribe({ topic => '/test', as_queue => '' }) },
          qr/Missing valid parameter 'as_queue'/,
          '... empty queue name, dies properly';
throws_ok sub { $sb->subscribe({ topic => '/test', on_message => '' }) },
          qr/Parameter 'on_message' must be a CODE ref, /,
          '... non-CODE-ref callback, dies properly';
TODO: {
  todo_skip('Not implemented yet', 1);
  throws_ok sub { $sb->subscribe({ topic => '/test', payload => '2321' }) },
            qr/Parameter unknown 'payload', /,
            '... unknown parameter, dies properly';
}

        