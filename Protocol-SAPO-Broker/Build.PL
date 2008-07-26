use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Protocol::SAPO::Broker',
    license             => 'perl',
    dist_author         => 'Pedro Melo <melo@cpan.org>',
    dist_version_from   => 'lib/Protocol/SAPO/Broker.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'Protocol-SAPO-Broker-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
