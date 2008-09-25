package App::SAPO::Broker::AgentMap;

use warnings;
use strict;
use base qw( Class::Accessor::Fast );
use IO::String;
use App::SAPO::Broker::Agent;

our $VERSION = '0.01';

__PACKAGE__->mk_ro_accessors(qw(
  worldmap_path agent_config_path
));

sub new {
  my ($class, $args) = @_;
  
  $args->{agents} ||= {};
  
  return $class->SUPER::new($args);
}


################
# Agent database

sub agent_count {
  my $self = shift;
  
  return scalar($self->agents);
}

sub agents {
  my ($self, $filters) = @_;
  my @agents = values %{$self->{agents}};

  return @agents unless $filters;
  return grep { $_->matches($filters) } @agents;
}

sub agent {
  my ($self, $name) = @_;
  my $agents = $self->{agents};

  return $agents->{$name} if exists $agents->{$name};
  return undef;
}


#######
# Parse

sub parse {
  my ($class, $text) = @_;

  my $fh = IO::String->new($text);

  my $active_parser = \&_parse_global_commands;
  my $stash = {
    agents   => [],
    defaults => {},
  };
  
  while (my $line = <$fh>) {
    $line = _strip_comments($line);
    next unless $line;
    
    my ($cmd, $arg) = split(/\s+/, $line, 2);
    my $done = 0;
    my $done_cb = sub { $done++ };
    while (!$done) {
      my $switch_to = $active_parser->($class, $cmd, $arg, $stash, $done_cb);
      $active_parser = $switch_to if $switch_to;
    }
  }
  $class->_clean_stash($stash);
    
  return $class->new($stash);  
}

sub _clean_stash {
  my ($class, $stash) = @_;
  
  delete $stash->{target};
  delete $stash->{defaults};
  
  my $parsed_agents = delete $stash->{agents};
  my %clean_agents;
  
  foreach my $agent (@$parsed_agents) {
    $class->_expand_vars($agent);
    
    $agent = App::SAPO::Broker::Agent->new($agent);
    die("Missing name on agent\n") unless $agent->name;
    
    my $name = $agent->name;
    die("Duplicate agent named '$name'\n") if exists $clean_agents{$name};
    
    $clean_agents{$name} = $agent;
  }
  
  $stash->{agents} = \%clean_agents;
  
  return;
}

sub _expand_vars {
  my ($class, $agent) = @_;
  
  while (my ($k, $v) = each %$agent) {
    $v =~ s/%%([\w-]+)%%/$agent->{$1} || ''/ge;
    $agent->{$k} = $v;
  }
}

sub _strip_comments {
  my $line = shift;
    
  $line =~ s/\s*#.+$//;
  $line =~ s/^\s+|\s+$//g;
  
  return $line;
}

sub _parse_global_commands {
  my ($class, $cmd, $arg, $stash, $done) = @_;

  return \&_parse_agent    if $cmd eq 'agent';
  return \&_parse_defaults if $cmd eq 'defaults';
  
  if ($cmd eq 'worldmap-path' || $cmd eq 'agent-config-path') {
    $cmd =~ s/-/_/g;
    $class->_parse_path($cmd, $arg, $stash);

    $done->();
    return undef;
  }
  
  die("Command '$cmd' unknown\n");
}

sub _parse_agent {
  my ($class, $cmd, $arg, $stash, $done) = @_;
  my %agent = %{$stash->{defaults}};
  
  push @{$stash->{agents}}, $stash->{target} = \%agent;
  
  $done->();
  return \&_parse_agent_info;
}

sub _parse_defaults {
  my ($class, $cmd, $arg, $stash, $done) = @_;
  
  $stash->{target} = $stash->{defaults} ||= {};

  $done->();
  return \&_parse_agent_info;
}

sub _parse_agent_info {
  my ($class, $cmd, $arg, $stash, $done) = @_;
  my $target = $stash->{target};
  
  my %cmds = (
    'name'             => \&_parse_string,
    'ip'               => \&_parse_ip,
    'peer-port'        => \&_parse_integer,
    'client-tcp-port'  => \&_parse_integer,
    'client-udp-port'  => \&_parse_integer,
    'client-http-port' => \&_parse_integer,
    'workspace-path'   => \&_parse_path,
    'dropbox-path'     => \&_parse_path,
    'dropbox-enabled'  => \&_parse_boolean,
    'dropbox-interval' => \&_parse_integer,
  );
   
  return \&_parse_global_commands unless exists $cmds{$cmd};
  
  my $parse_f = $cmds{$cmd};
  $cmd =~ s/-/_/g;
  $parse_f->($class, $cmd, $arg, $target);
  
  $done->();
  return;
}

sub _parse_string {
  my ($class, $cmd, $arg, $stash) = @_;

  $arg =~ s/^(['"])(.+)\1$/$2/;
  $stash->{$cmd} = $arg;
}

sub _parse_integer {
  my ($class, $cmd, $arg, $stash) = @_;
  
  die("Invalid integer argument ('$arg') to command '$cmd'\n")
    unless $arg =~ m/^\d+$/;
  $stash->{$cmd} = $arg;
}

sub _parse_ip {
  my ($class, $cmd, $arg, $stash) = @_;
  
  die("Invalid IP argument ('$arg') to command '$cmd'\n")
    unless $arg =~ m/^\d+[.]\d+[.]\d+[.]\d+$/;
  $stash->{$cmd} = $arg;
}

sub _parse_boolean {
  my ($class, $cmd, $arg, $stash) = @_;
  
  my %valid = (
    'true'  => 1,
    'yes'   => 1,
    'on'    => 1,
    '1'     => 1,
    'false' => 0,
    'no'    => 0,
    'off'   => 0,
    '0'     => 0,
  );
  die("Invalid boolean argument ('$arg') to command '$cmd'\n")
    unless exists $valid{$arg};
  $stash->{$cmd} = $valid{$arg};
}

sub _parse_path { my $class = shift; $class->_parse_string(@_) }


=head1 NAME

App::SAPO::Broker::AgentMap - Parses Agent Map configuration file

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS

    use App::SAPO::Broker::AgentMap;
    
    my $agent_map = App::SAPO::Broker::AgentMap->parse($string);
    

=head1 DESCRIPTION

...

=head1 AUTHOR

Pedro Melo, C<< <melo at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-app-sapo-broker at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-SAPO-Broker>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::SAPO::Broker


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-SAPO-Broker>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-SAPO-Broker>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-SAPO-Broker>

=item * Search CPAN

L<http://search.cpan.org/dist/App-SAPO-Broker>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 Pedro Melo.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of App::SAPO::Broker
