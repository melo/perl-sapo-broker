#!/bin/sh
#
# Install all modules
#

for d in Protocol-SAPO-Broker Net-SAPO-Broker App-SAPO-Broker-Utils ; do
  ( cd $d && cpan . )
done
