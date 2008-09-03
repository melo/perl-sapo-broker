#!perl -T

use Test::Most tests => 1;

BEGIN {
	use_ok( 'App::SAPO::Broker::AgentMap' );
}

explain( "Testing App::SAPO::Broker::AgentMap $App::SAPO::Broker::AgentMap::VERSION, Perl $], $^X" );

my $sample_config = q{
worldmap_path     /path/to/worlmap
agent_config_path /path/to/config

# You can have comments
defaults
  name "agent-%%ip%%-%%peer_port%%"  # %%name%% is replaced with name var
  peer_port 3333
  client-tcp-port 3269
  client-udp-port 3269
  client-http-port 3280
  workspace_path "/path/to/work"
  dropbox_path  /path/to/dropbox
  dropbox_enabled true
  dropbox_interval 5

agent
  ip 127.0.0.1

agent
  ip 127.0.0.2

# You can have several sets of defaults
defaults
  peer_port 4444
  client-tcp-port 4449     # As you can see above, end-of-line comments
  client-udp-port 4449     # are ok
  dropbox_path  /not/to/dropbox

agent
  ip 127.0.0.3

agent
  ip 127.0.0.4
  dropbox_enabled false

};

my $am = App::SAPO::Broker::AgentMap->new;
lives_ok sub { $am->parse($sample_config) }, 'Parsed configuration file ok';

is($am->worldmap_path,     '/path/to/worlmap', 'Correct worlmap path');
is($am->agent_config_path, '/path/to/config',  'Correct config path');

is($am->agent_count, 4, 'Correct number of agents ');

foreach my $agent_name ($am->agents) {
  my $cfg = $am->agent($agent_name);
  
  is($cfg->client_http_port, 3280, "HTTP client port for $agent_name ok");
  is($cfg->workspace_path, '/path/to/work', "Workspace for $agent_name ok");
  is($cfg->dropbox_interval, 5, "Dropbox interval for $agent_name ok");
  
  my $ip = $cfg->ip;
  my $peer_port = $cfg->peer_port;
  my $name = "agent-$ip-$peer_port";
  is($agent_name, $name, 'Agent name from agents() is consistent');
  is($cfg->name, $name, 'Agent name is in the proper format');
}

my (@cfg) = $am->agents({ ip => 127.0.0.1 });
ok(@cfg, 'Found agent for IP 127.0.0.1');
is(scalar(@cfg), 1, '... a single agent as expected');

my $cfg = $am->agent($cfg[0]->name);
ok($cfg, 'Fetch by name also works');
is($cfg, $cfg[0], '... and we get the same object');

my $name = $cfg->name;
is($cfg->name,             'agent-127.0.0.1-3333', "Proper name for agent '$name'");
is($cfg->ip,               '127.0.0.1',            "Proper IP for agent '$name'");
is($cfg->peer_port,        3333,                   "Proper peer_port for agent '$name'");
is($cfg->client_tcp_port,  3269,                   "Proper client tcp port for agent '$name'");
is($cfg->client_udp_port,  3269,                   "Proper client udp port for agent '$name'");
is($cfg->client_http_port, 3280,                   "Proper client http port for agent '$name'");
is($cfg->workspace_path,   '/path/to/work',        "Proper workspace path for agent '$name'");
is($cfg->dropbox_path,     '/path/to/dropbox',     "Proper dropbox path for agent '$name'");
ok($cfg->dropbox_enabled,                          "Dropbox is enabled for agent '$name'");
is($cfg->dropbox_interval, 5,                      "Proper dropbox interval for agent '$name'");

($cfg) = $am->agents({ ip => 127.0.0.2 });
$name = $cfg->name;
is($cfg->name,             'agent-127.0.0.2-3333', "Proper name for agent '$name'");
is($cfg->ip,               '127.0.0.2',            "Proper IP for agent '$name'");
is($cfg->peer_port,        3333,                   "Proper peer_port for agent '$name'");
is($cfg->client_tcp_port,  3269,                   "Proper client tcp port for agent '$name'");
is($cfg->client_udp_port,  3269,                   "Proper client udp port for agent '$name'");
is($cfg->client_http_port, 3280,                   "Proper client http port for agent '$name'");
is($cfg->workspace_path,   '/path/to/work',        "Proper workspace path for agent '$name'");
is($cfg->dropbox_path,     '/path/to/dropbox',     "Proper dropbox path for agent '$name'");
ok($cfg->dropbox_enabled,                          "Dropbox is enabled for agent '$name'");
is($cfg->dropbox_interval, 5,                      "Proper dropbox interval for agent '$name'");


($cfg) = $am->agents({ ip => 127.0.0.3 });
$name = $cfg->name;
is($cfg->name,             'agent-127.0.0.2-3333', "Proper name for agent '$name'");
is($cfg->ip,               '127.0.0.2',            "Proper IP for agent '$name'");
is($cfg->peer_port,        4444,                   "Proper peer_port for agent '$name'");
is($cfg->client_tcp_port,  4449,                   "Proper client tcp port for agent '$name'");
is($cfg->client_udp_port,  4449,                   "Proper client udp port for agent '$name'");
is($cfg->client_http_port, 3280,                   "Proper client http port for agent '$name'");
is($cfg->workspace_path,   '/path/to/work',        "Proper workspace path for agent '$name'");
is($cfg->dropbox_path,     '/not/to/dropbox',      "Proper dropbox path for agent '$name'");
ok($cfg->dropbox_enabled,                          "Dropbox is enabled for agent '$name'");
is($cfg->dropbox_interval, 5,                      "Proper dropbox interval for agent '$name'");

($cfg) = $am->agents({ ip => 127.0.0.4 });
$name = $cfg->name;
is($cfg->name,             'agent-127.0.0.2-3333', "Proper name for agent '$name'");
is($cfg->ip,               '127.0.0.2',            "Proper IP for agent '$name'");
is($cfg->peer_port,        4444,                   "Proper peer_port for agent '$name'");
is($cfg->client_tcp_port,  4449,                   "Proper client tcp port for agent '$name'");
is($cfg->client_udp_port,  4449,                   "Proper client udp port for agent '$name'");
is($cfg->client_http_port, 3280,                   "Proper client http port for agent '$name'");
is($cfg->workspace_path,   '/path/to/work',        "Proper workspace path for agent '$name'");
is($cfg->dropbox_path,     '/not/to/dropbox',      "Proper dropbox path for agent '$name'");
ok(!$cfg->dropbox_enabled,                         "Dropbox is NOT enabled for agent '$name'");
is($cfg->dropbox_interval, 5,                      "Proper dropbox interval for agent '$name'");