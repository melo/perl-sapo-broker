package App::SAPO::Broker::AgentMap;

use warnings;
use strict;
use base qw( Class::Accessor::Fast );

our $VERSION = '0.01';

__PACKAGE__->mk_ro_accessors(qw(
  worldmap_path agent_config_path
));

sub new {
  my ($class, $args) = @_;
  
  $args->{agents} = {};
  
  return $class->SUPER::new($args);
}


################
# Agent database

sub agent_count {
  my $self = shift;
  
  return scalar($self->agents);
}

sub agents {
  my $self = shift;
  
  return values %{$self->{agents}};
}

sub agent {
  my ($self, $name) = @_;
  my $agents = $self->{agents};

  return $agents->{$name} if exists $agents->{$name};
  return undef;
}



=head1 NAME

App::SAPO::Broker::AgentMap - Parses Agent Map configuration file

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS

    use App::SAPO::Broker::AgentMap;
    
    my $agent_map = App::SAPO::Broker::AgentMap->new;
    
    # Parse a string with the configuration
    eval { $agent_map->parse($agent_map) };
    
    # Parse a open file with the configuration
    eval { $agent_map->parse($fh) };
    

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

Copyright 2008 Pedro Melo, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of App::SAPO::Broker
