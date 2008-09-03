#!perl -T

use strict;
use warnings;
use Test::More;

plan skip_all => "Use TEST_AUTHOR=1 to test pod stuff"
  unless $ENV{TEST_AUTHOR};

# Ensure a recent version of Test::Pod
my $min_tp = 1.22;
eval "use Test::Pod $min_tp";
plan skip_all => "Test::Pod $min_tp required for testing POD" if $@;

all_pod_files_ok();
