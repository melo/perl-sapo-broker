#!perl -T

use Test::Most tests => 1;

BEGIN {
	use_ok( 'App::SAPO::Broker' );
}

explain( "Testing App::SAPO::Broker $App::SAPO::Broker::VERSION, Perl $], $^X" );
