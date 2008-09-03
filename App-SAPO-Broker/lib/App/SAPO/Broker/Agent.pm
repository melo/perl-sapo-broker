package App::SAPO::Broker::Agent;

use warnings;
use strict;
use base qw( Class::Accessor::Fast );

our $VERSION = '0.01';

__PACKAGE__->mk_ro_accessors(qw(
  name ip
  peer_port client_tcp_port client_udp_port client_http_port
  workspace_path
  dropbox_path dropbox_enabled dropbox_interval
));


=head1 NAME

App::SAPO::Broker::Agent - a single Agent in the AgentMap

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS

    use App::SAPO::Broker::AgentMap;
    
    my $agent_map = App::SAPO::Broker::AgentMap->new;
    eval { $agent_map->parse($agent_map) };
    my $agent = $agent_map->agent('some_name');
    
    $agent->methods...


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
