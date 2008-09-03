#!perl -T

use Test::Most tests => 1;

BEGIN {
	use_ok( 'App::SAPO::Broker::AgentMap' );
}

explain( "Testing App::SAPO::Broker::AgentMap $App::SAPO::Broker::AgentMap::VERSION, Perl $], $^X" );
