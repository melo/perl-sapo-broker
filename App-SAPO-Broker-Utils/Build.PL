use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'App::SAPO::Broker::Utils',
    license             => 'perl',
    dist_author         => 'Pedro Melo <melo@cpan.org>',
    dist_version_from   => 'lib/App/SAPO/Broker/Utils.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'App-SAPO-Broker-Utils-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
