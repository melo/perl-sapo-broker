#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Net::SAPO::Broker' );
}

diag( "Testing Net::SAPO::Broker $Net::SAPO::Broker::VERSION, Perl $], $^X" );
