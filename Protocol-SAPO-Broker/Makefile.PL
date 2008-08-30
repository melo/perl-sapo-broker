use inc::Module::Install;

# Define metadata
name     'Protocol-SAPO-Broker';
all_from 'lib/Protocol/SAPO/Broker.pm';

# Specific dependencies
requires 'Carp::Clan'             => 0;
requires 'Errno'                  => 0;
requires 'XML::LibXML'            => 0;
requires 'Class::Accessor::Fast'  => 0;
requires 'Test::Most'             => 0;

# Meta
repository 'http://github.com/melo/perl-sapo-broker';

WriteAll;
