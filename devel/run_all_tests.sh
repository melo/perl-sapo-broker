#!/bin/sh

export PERL5LIB=`pwd`/Protocol-SAPO-Broker/lib

if [ -n "$SMOLDER_REPORT" ] ; then
  prove_cmd='prove -l -v --archive smoke.tar.gz'
elif [ -n "$TEST_USE_HTML_REPORT" ] ; then
	prove_cmd='prove -l -m -Q --formatter=TAP::Formatter::HTML > output.html ; open output.html'
else
  prove_cmd='prove -l -v'
fi

for dir in Protocol-SAPO-Broker Net-SAPO-Broker App-SAPO-Broker ; do
  sh -c "cd $dir && perl Makefile.PL && make && $prove_cmd"
done
