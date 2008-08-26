#!/bin/sh

PERL5LIB=Protocol-SAPO-Broker/lib:Net-SAPO-Broker/lib
export PERL5LIB

exec App-SAPO-Broker-Utils/script/sapo-broker-client $@
