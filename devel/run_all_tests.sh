#!/bin/sh

export PERL5LIB=`pwd`/Protocol-SAPO-Broker/lib

(
  cd Protocol-SAPO-Broker
  prove -l -v t/[0-9]*
)

(
  cd Net-SAPO-Broker
  prove -l -v t/0*
)

