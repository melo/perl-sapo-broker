use inc::Module::Install;

# Define metadata
name     'Net-SAPO-Broker';
all_from 'lib/Net/SAPO/Broker.pm';

# Specific dependencies
requires 'Protocol::SAPO::Broker' => '0.01';
requires 'Carp::Clan'             => 0;
requires 'Errno'                  => 0;
requires 'Time::HiRes'            => 0;
requires 'Test::Most'             => 0;

# Meta
repository 'http://github.com/melo/perl-sapo-broker';

WriteAll;
