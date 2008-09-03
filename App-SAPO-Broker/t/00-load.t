#!perl -T

use Test::Most tests => 3;

BEGIN {
	use_ok( 'App::SAPO::Broker::Agent' );
	use_ok( 'App::SAPO::Broker::AgentMap' );
	use_ok( 'App::SAPO::Broker' );
}

explain( "Testing App::SAPO::Broker $App::SAPO::Broker::VERSION, Perl $], $^X" );
explain( "Testing App::SAPO::Broker::AgentMap $App::SAPO::Broker::AgentMap::VERSION, Perl $], $^X" );
explain( "Testing App::SAPO::Broker::Agent $App::SAPO::Broker::Agent::VERSION, Perl $], $^X" );
