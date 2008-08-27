use inc::Module::Install;

# Define metadata
name         'App-SAPO-Broker-Utils';
abstract     'Command line utilities to use with SAPO Broker';
author       'Pedro Melo <melo@simplicidade.org>';
version      '0.01';
license      'perl';
perl_version '5.006';

# scripts mostly
install_script "sapo-broker-client";

# Specific dependencies
requires 'Net::SAPO::Broker' => '0.01';
requires 'Getopt::Long'      => 0;
requires 'Time::HiRes'       => 0;
requires 'LWP::UserAgent'    => 0;
requires 'Benchmark'         => 0;
requires 'XML::LibXML'       => 0;
requires 'XML::LibXML::XPathContext' => 0;

# Meta
repository 'http://github.com/melo/perl-sapo-broker';

WriteAll;
