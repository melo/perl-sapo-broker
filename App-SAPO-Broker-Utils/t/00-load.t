#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'App::SAPO::Broker::Utils' );
}

diag( "Testing App::SAPO::Broker::Utils $App::SAPO::Broker::Utils::VERSION, Perl $], $^X" );
