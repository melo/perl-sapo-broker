#!perl

use strict;
use warnings;
use Test::Most 'no_plan';
use App::SAPO::Broker::AgentMap;

### Test _strip_comments function

my @patts = (
  [ ''                             => ''              ],
  [ "\n"                           => ''              ],
  [ "   \n"                        => ''              ],
  [ ' '                            => ''              ],
  [ ' # asdsa '                    => ''              ],
  [ 'aaa#bbb'                      => 'aaa'           ],
  [ ' aaa#bbb'                     => 'aaa'           ],
  [ ' aaaa aaaa aaa # bbb # bbb'   => 'aaaa aaaa aaa' ],
  [ " aaaa aaaa aaa # bbb # bbb\n" => 'aaaa aaaa aaa' ],
);

foreach my $patt (@patts) {
  is(App::SAPO::Broker::AgentMap::_strip_comments($patt->[0]), $patt->[1]);
}

### Test _parse_string function

@patts = (
  [ ''     => ''   ],
  [ "aa"   => 'aa' ],
  [ "'bb'" => 'bb' ],
  [ '"cc"' => 'cc' ],
);

foreach my $patt (@patts) {
  my $stash = {};
  App::SAPO::Broker::AgentMap->_parse_string('test', $patt->[0], $stash);
  is($stash->{test}, $patt->[1]);
}


### Test _parse_integer function

@patts = (
  [ '1'  => '1'  ],
  [ "22" => '22' ],
);

foreach my $patt (@patts) {
  my $stash = {};
  App::SAPO::Broker::AgentMap->_parse_integer('test', $patt->[0], $stash);
  is($stash->{test}, $patt->[1]);
}


### Test _parse_ip function

@patts = (
  [ '1.1.1.1'     => '1.1.1.1'     ],
  [ '00.00.00.00' => '00.00.00.00' ],
);

foreach my $patt (@patts) {
  my $stash = {};
  App::SAPO::Broker::AgentMap->_parse_ip('test', $patt->[0], $stash);
  is($stash->{test}, $patt->[1]);
}


### Test _parse_boolean function

@patts = (
  [ 'true'  => 1 ],
  [ 'yes'   => 1 ],
  [ 'on'    => 1 ],
  [ '1'     => 1 ],
  [ 'false' => 0 ],
  [ 'no'    => 0 ],
  [ 'off'   => 0 ],
  [ '0'     => 0 ],
);

foreach my $patt (@patts) {
  my $stash = {};
  App::SAPO::Broker::AgentMap->_parse_boolean('test', $patt->[0], $stash);
  is($stash->{test}, $patt->[1]);
}


### Test _parse_path function

@patts = (
  [ './asd/assd'            => './asd/assd'          ],
  [ "/asdasd/asdasd"        => '/asdasd/asdasd'      ],
  [ "'./asd asdas/asd asd'" => './asd asdas/asd asd' ],
  [ "'./asd asdas/asd asd'" => './asd asdas/asd asd' ],
  [ "'/asd asdas/asd asd'"  => '/asd asdas/asd asd'  ],
  [ "'/asd asdas/asd asd'"  => '/asd asdas/asd asd'  ],
);

foreach my $patt (@patts) {
  my $stash = {};
  App::SAPO::Broker::AgentMap->_parse_path('test', $patt->[0], $stash);
  is($stash->{test}, $patt->[1]);
}


### Test _expand_vars function

@patts = (
  [
    { f1 => 'aa %%f2%% %%f3%%', f2 => 'bb', f3 => 'cc' },
    { f1 => 'aa bb cc',         f2 => 'bb', f3 => 'cc' },
  ],
  [
    { f1 => 'aa %% f2%% %%f3%%', f2 => 'bb', f3 => 'cc' },
    { f1 => 'aa %% f2%% cc',     f2 => 'bb', f3 => 'cc' },
  ],
  [
    { f1 => 'aa %%f2 %% %%f3%%', f2 => 'bb', f3 => 'cc' },
    { f1 => 'aa %%f2 %% cc',     f2 => 'bb', f3 => 'cc' },
  ],
  [
    { f1 => 'aa %% %% %%f3%%', f2 => 'bb', f3 => 'cc' },
    { f1 => 'aa %% %% cc',     f2 => 'bb', f3 => 'cc' },
  ],
  [
    { f1 => 'aa %  %% %%f3%%', f2 => 'bb', f3 => 'cc' },
    { f1 => 'aa %  %% cc',     f2 => 'bb', f3 => 'cc' },
  ],
  [
    { f1 => 'aa %  %%f2%%f3%%', f2 => 'bb', f3 => 'cc' },
    { f1 => 'aa %  bbf3%%',     f2 => 'bb', f3 => 'cc' },
  ],
);

foreach my $patt (@patts) {
  my ($try, $match) = @$patt;
  App::SAPO::Broker::AgentMap->_expand_vars($try);
  cmp_deeply($try, $match);
}
