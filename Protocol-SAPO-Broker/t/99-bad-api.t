#!perl -T

use strict;
use warnings;
use Test::Most 'no_plan';
use Protocol::SAPO::Broker;

# new() (wrong API, failures)
throws_ok sub { Protocol::SAPO::Broker->new },
          qr/Missing callback 'on_connect', /,
          'Missing required parameters (connect callback)';
throws_ok sub { Protocol::SAPO::Broker->new({ on_connect => '' }) },
          qr/Invalid callback 'on_connect', /,
          'Missing required parameters (on_connect callback)';
throws_ok sub { Protocol::SAPO::Broker->new({ on_connect => sub {} }) },
          qr/Missing callback 'on_send', /,
          'Missing required parameters (on_send callback)';
throws_ok sub {
            Protocol::SAPO::Broker->new({
              on_connect => sub {},
              on_send => ''
            })
          },
          qr/Invalid callback 'on_send', /,
          'Missing required parameters (on_send callback)';


my $sb = Protocol::SAPO::Broker->new({
  auto_connect => 0,
  on_connect   => sub { $_[0]->connected },
  on_send      => sub {},
});


# Catch API usage while not connected
throws_ok sub { $sb->publish() },
          qr/Cannot call 'publish\(\)': state is 'idle', requires 'connected', /,
          'Not connected, publish() dies';
throws_ok sub { $sb->subscribe() },
          qr/Cannot call 'subscribe\(\)': state is 'idle', requires 'connected', /,
          'Not connected, subscribe() dies';
throws_ok sub { $sb->enqueue() },
          qr/Cannot call 'enqueue\(\)': state is 'idle', requires 'connected', /,
          'Not connected, enqueue() dies';
throws_ok sub { $sb->poll() },
          qr/Cannot call 'poll\(\)': state is 'idle', requires 'connected', /,
          'Not connected, poll() dies';
throws_ok sub { $sb->ack() },
          qr/Cannot call 'ack\(\)': state is 'idle', requires 'connected', /,
          'Not connected, ack() dies';

throws_ok sub { $sb->disconnect() },
          qr/Cannot call 'disconnect\(\)': state is 'idle', requires 'connected', /,
          'Not connected, disconnect() dies';



$sb->connect;

throws_ok sub { $sb->connect() },
          qr/Cannot call 'connect\(\)': state is 'connected', requires 'idle', /,
          'Already connected, connect() again dies';

# publish() (wrong API, failures)
explain("Testing publish() API failures");
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
explain("Testing subscribe() API failures");
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


# ack() (wrong API, failures)
explain("Testing ack() API failures");
throws_ok sub { $sb->ack() },
          qr/Missing required parameter/,
          '... no parameters, dies properly';
throws_ok sub { $sb->ack({}) },
          qr/Missing required parameter/,
          '... empty param hashref, dies properly';
throws_ok sub { $sb->ack({ queue => '' }) },
          qr/Missing valid parameter 'queue'/,
          '... empty queue, dies properly';
throws_ok sub { $sb->ack({ id => '1' }) },
          qr/Missing required parameter 'queue'/,
          '... misssing queue, dies properly';
throws_ok sub { $sb->ack({ queue => 'q1' }) },
          qr/Missing required parameter 'id'/,
          '... missing id, dies properly';
throws_ok sub { $sb->ack({ queue => 'q1', id => '' }) },
          qr/Missing valid parameter 'id'/,
          '... empty id, dies properly';


# enqueue() (wrong API, failures)
explain("Testing enqueue() API failures");
throws_ok sub { $sb->enqueue() },
          qr/Missing required parameter/,
          '... no parameters, dies properly';
throws_ok sub { $sb->enqueue({}) },
          qr/Missing required parameter/,
          '... empty param hashref, dies properly';
throws_ok sub { $sb->enqueue({ queue => '' }) },
          qr/Missing valid parameter 'queue'/,
          '... empty queue, dies properly';
throws_ok sub { $sb->enqueue({ payload => '' }) },
          qr/Missing required parameter 'queue'/,
          '... missing queue, dies properly';
throws_ok sub { $sb->enqueue({ topic => '/test' }) },
          qr/Missing required parameter 'queue'/,
          '... missing queue, add as_queue to fix, dies properly';
throws_ok sub { $sb->enqueue({ queue => '/test' }) },
          qr/Missing required parameter 'payload'/,
          '... missing payload, dies properly';


# poll() (wrong API, failures)
explain("Testing poll() API failures");
throws_ok sub { $sb->poll() },
          qr/Missing required parameter/,
          '... no parameters, dies properly';
throws_ok sub { $sb->poll({}) },
          qr/Missing required parameter/,
          '... empty param hashref, dies properly';
throws_ok sub { $sb->poll({ queue => '' }) },
          qr/Missing valid parameter 'queue'/,
          '... empty queue, dies properly';
throws_ok sub { $sb->poll({ topic => '/test' }) },
          qr/Missing required parameter 'queue'/,
          '... missing queue, add as_queue to fix, dies properly';
