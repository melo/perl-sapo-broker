Perl SAPO Broker clients
========================

This is a set of modules to work with the [SAPO Broker](http://softwarelivre.sapo.pt/broker/) messaging system.

The main logic is in Protocol::SAPO::Broker Perl module, and the others like Net::SAPO::Broker provide the network code.

This allows us to write AnyEvent::SAPO::Broker, Danga::SocketX::SAPO::Broker and even POE::Component::SAPO::Broker using the same tested state machine.

Also included is the App::SAPO::Broker that include a command line tool, `sapo-broker-client`, that allows you to test your SAPO Broker cloud.


Status
======

The code works, and most operations are implemented. The API is still in flux,
so I'm labelling the current version as alpha.

We have a proper test suite, and code coverage reports indicate above 95%
coverage.


Roadmap
=======

First CPAN release will be 0.5, that includes:

 * all SAPO Broker operations: Publish, Notify, Enqueue, Poll, Ack,
     CheckStatus;
 * initial version of the documentation: will not be complete, but should
     allow you to get started;
 * Modules included: Protocol::SAPO::Broker and Net::SAPO::Broker.


After that, we will complete the documentation (release 0.6), and then do the AnyEvent version (0.7) and the Danga::SocketX (0.8).

From then on, tweaks, docs, TBD stuff. 0.9 is the final test release.

From 0.9 to 1.0 we will release 0.9.X releases to fix problems reported by
the CPAN testers network.


TODO
====

Protocol::SAPO::Broker
----------------------

 * Add unsusbcribe()
 * Add check_status()
 * Add auto_reconnect
 * Document public API
 * Document implementation API
 * Disconnect should be a two-step process: init disconnect, and a impl callback disconnected()
 * Add impl_ prefix to all implementation callbacks
 * add tests for calls to connect() and connect_error() while in 'reconnecting'

Net::SAPO::Broker
-----------------

 * if any of enqueue, publish, subscribe use an action-id, make them block 
     until a reply is received;
 * split deliver_messages into deliver_one_message, wait_for_message_id, and
     deliver_all_messages.
 * Make sure they react well to auto_connect and auto_reconnect settings


AnyEvent::SAPO::Broker
======================

 * Write it :)


Danga::SocketX::SAPO::Broker
============================

 * Write it :)


App::SAPO::Broker
=================

sapo-broker-client
------------------

 * --raw-xml: dumps raw-xml
 * --pretty-xml: dumps raw-xml, prettyfied
 * clear queue operations: --remove becomes --remove-queue and queue_id is in
     @ARGV: allows for multiple queue removal
 * --binary-filter: for --publish - coverts \0-\31, \128-\255 and \ to
     \-prefixed - clean UTF8 transport for binary data
   * useful for tail -f log_file where log file might contain binary data
 * --as_queue: to use with --subscribe, sends acks automatically
 * --enqueue: queue stuff
 * --poll: unqueue stuff up - automatically calls ack and pools again
 * --interactive: add on to --poll - allows you to poll, ack on demand. A
     "Thank you sir, can I have another"-style interface.
 * --discover-max-rate: a load-generator/collector add on - it increases the 
     load on a topic until one of the subscribers starts losing messages. Then
     it does a binary search between the last two values for rate.


sapo-broker-top
---------------

 * collect /system/stats and show a top-like interface


sapo-broker-startup
-------------------

 * starts a Agent instance:
   * create config.xml based on command line parameters;
   * converts simple-style world_map to XML version;
   * only starts agent if IP of server is in world_map:
     * allows you to have sapo-broker-startup on your cluster diskimage
       but only servers that are placed in the world_map will launch the agent


sapo-broker-world-map-sync
--------------------------

Broker-based system to distribute the world map.

Not sure its a good idea though.



Docs to write
=============

Wiki
----

 * History;
 * Protocol:
   * Per message:
     * XML sample;
     * Explanation of each field.
 * Flows:
   * Publish a message (with and without ack);
   * Subscribe a topic (with, without ack):
     * wildcard topics;
     * topic as queue;
   * Queue and Poll
 * Use cases:
   * high-performance crawler with AnyEvent;
   * ad-hoc log collector;


