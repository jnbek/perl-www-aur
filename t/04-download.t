#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 7;
use File::Spec::Functions qw(rel2abs splitpath catdir);

use WWW::AUR::Package;

my (undef, $tmpdir, undef) = splitpath( $0 );
$tmpdir = rel2abs( $tmpdir );
$tmpdir = catdir( $tmpdir, 'tmp' );

my $pkg = WWW::AUR::Package->new( 'perl-cpanplus-dist-arch',
                                  'basepath' => $tmpdir );
ok $pkg, 'looked up perl-cpanplus-dist-arch package';

my $download_size = $pkg->download_size();
ok $download_size > 0, 'web download size';

ok my $pkgfile = $pkg->download();
ok -f $pkgfile, 'source package file was downloaded';
ok $download_size == (-s $pkgfile),
    'downloaded file size matches the web reported size';

$pkg = WWW::AUR::Package->new( 'perl-archlinux-messages',
                               'basepath' => $tmpdir );
ok $pkg, 'looked up perl-archlinux-messages package';

my $done = 0;
my $cb = sub {
    my ($dl, $total) = @_;
    $done = 1 if $dl == $total;
};
$pkg->download( $cb );
ok $done, 'download callback works';