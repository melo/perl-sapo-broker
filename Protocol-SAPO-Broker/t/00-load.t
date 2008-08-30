#!perl -T

use Test::Most tests => 1;

BEGIN {
	use_ok( 'Protocol::SAPO::Broker' );
}

explain( "Testing Protocol::SAPO::Broker $Protocol::SAPO::Broker::VERSION, Perl $], $^X" );
