#!/usr/bin/perl

use warnings;
use strict;
use Test::More qw(no_plan);

use WWW::AUR::Maintainer;

my $who = WWW::AUR::Maintainer->new( 'juster' );
ok $who;

my $found = 0;
for my $pkg ( $who->packages ) {
    if ( $pkg->{name} eq 'perl-cpanplus-dist-arch' ) { $found = 1; }
}
ok $found, 'found perl-cpanplus-dist-arch, owned by juster';

eval { WWW::AUR::Maintainer->new( 'bkajsdlfk' ) };
like $@, qr/\ACould not find a maintainer named "bkajsdlfk"/;
