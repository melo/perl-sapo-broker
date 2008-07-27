#!perl -T

use Test::More tests => 3;

BEGIN {
	use_ok( 'Net::SAPO::Broker' );
}

diag( "Testing Net::SAPO::Broker $Net::SAPO::Broker::VERSION, Perl $], $^X" );

my $sb = Net::SAPO::Broker->new;
ok($sb);
is($sb->state, 'connected');
