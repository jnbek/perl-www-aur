#!/usr/bin/perl

use warnings;
use strict;
use Test::More qw(no_plan);

use WWW::AUR::Package;

sub pbtext_ok
{
    my ($pbtext, $expect_ref, $test_name) = @_;

    my %parsed = WWW::AUR::Package::_pkgbuild_fields( $pbtext );
    is_deeply( \%parsed, $expect_ref, $test_name );
    return;
}

my $pbtext = <<'END_PKGBUILD';
pkgname='perl-cpanplus-dist-arch-git'
pkgver='20100530'
pkgrel='1'
pkgdesc='Developer release for CPANPLUS::Dist::Arch perl module'
arch=('any')
license=('PerlArtistic' 'GPL')
options=('!emptydirs')
makedepends=('perl-test-pod-coverage' 'perl-test-pod')
depends=('perl')
provides=('perl-cpanplus-dist-arch')
url='http://github.com/juster/perl-cpanplus-dist-arch'
md5sums=()
source=()
END_PKGBUILD

pbtext_ok( $pbtext,
           { 'pkgname'  => 'perl-cpanplus-dist-arch-git',
             'pkgver'   => '20100530',
             'pkgrel'   => '1',
             'pkgdesc'  => ( 'Developer release for CPANPLUS::Dist::Arch '
                             . 'perl module' ),
             'arch'     => [ 'any' ],
             'license'  => [ 'PerlArtistic', 'GPL' ],
             'options'  => [ '!emptydirs' ],
             'makedepends' => [ 'perl-test-pod-coverage',
                                'perl-test-pod' ],
             'depends'  => [ { 'pkg' => 'perl',
                               'cmp' => '>',
                               'ver' => '0',
                               'str' => 'perl', } ],
             'provides' => [ 'perl-cpanplus-dist-arch' ],
             'conflicts' => [], # an empty list is stored
             'url'      => 'http://github.com/juster/perl-cpanplus-dist-arch',
             'md5sums'  => [],
             'source'   => [] },
           'perl-cpanplus-dist-arch-git PKGBUILD parses' );

$pbtext = <<'END_PKGBUILD';
pkgname='depends-string-test'
depends=('dep>=0.01' 'dep-two')
conflicts=('conflict<999.999' 'conflict-two')
END_PKGBUILD

my %parsed = WWW::AUR::Package::_pkgbuild_fields( $pbtext );
is_deeply( $parsed{depends}, [ { 'pkg' => 'dep',
                                 'ver' => '0.01',
                                 'cmp' => '>=',
                                 'str' => 'dep>=0.01',
                                },
                               { 'pkg' => 'dep-two',
                                 'ver' => '0',
                                 'cmp' => '>',
                                 'str' => 'dep-two',
                                }]);
is_deeply( $parsed{conflicts}, [ { 'pkg' => 'conflict',
                                   'ver' => '999.999',
                                   'cmp' => '<',
                                   'str' => 'conflict<999.999',
                                  },
                                 { 'pkg' => 'conflict-two',
                                   'ver' => '0',
                                   'cmp' => '>',
                                   'str' => 'conflict-two',
                                  }]);
