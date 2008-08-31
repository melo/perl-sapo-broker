#!perl -T

use Test::Most tests => 1;

BEGIN {
	use_ok( 'Net::SAPO::Broker' );
}

explain( "Testing Net::SAPO::Broker $Net::SAPO::Broker::VERSION, Perl $], $^X" );
