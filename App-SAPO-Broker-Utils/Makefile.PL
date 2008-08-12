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

WriteAll;
