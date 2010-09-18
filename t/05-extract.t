#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 3;
use File::Spec::Functions qw(rel2abs splitpath catdir);

my (undef, $tmpdir, undef) = splitpath( $0 );
$tmpdir = rel2abs( $tmpdir );
$tmpdir = catdir( $tmpdir, 'tmp' );

use WWW::AUR::Package;
my $pkg = WWW::AUR::Package->new( 'perl-alpm', basepath => $tmpdir );
ok $pkg;

my $srcpkgdir = $pkg->extract();
ok $srcpkgdir, 'extract appears to succeed';
is $srcpkgdir, $pkg->srcpkg_dir(), 'extract() result matches srcpkg_dir()';
