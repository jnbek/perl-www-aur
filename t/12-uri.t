#!perl

use warnings;
use strict;
use Test::More;
use WWW::AUR::URI qw(:all);

my $pkgs = "http://aur.archlinux.org/packages";
is pkgfile_uri('f'), "$pkgs/f/f/f.tar.gz";
is pkgfile_uri('fo'), "$pkgs/fo/fo/fo.tar.gz";
is pkgfile_uri('foo'), "$pkgs/fo/foo/foo.tar.gz";

is pkgbuild_uri('bar'), "$pkgs/ba/bar/PKGBUILD";
is pkgbuild_uri('ba'), "$pkgs/ba/ba/PKGBUILD";
is pkgbuild_uri('b'), "$pkgs/b/b/PKGBUILD";

my $rpc = "http://aur.archlinux.org/rpc.php";
my $arg = "arg%5B%5D";
is rpc_uri('minfo', qw/foo bar/), "$rpc?type=minfo&$arg=foo&$arg=bar";
is rpc_uri('info', qw/foo bar/),  "$rpc?type=info&arg=foo";
is rpc_uri('info', 'foo'), rpc_uri('info', qw/foo bar/);

is rpc_uri('search', 'foo'), "$rpc?type=search&arg=foo";
is rpc_uri('search', 'foo'), "$rpc?type=search&arg=foo";
is rpc_uri('msearch', 'juster'), "$rpc?type=msearch&arg=juster";

$WWW::AUR::URI::Scheme = 'https';
s/^http/https/ for $rpc, $pkgs;

is rpc_uri('search', 'foo'), "$rpc?type=search&arg=foo";
is pkgfile_uri('foo'), "$pkgs/fo/foo/foo.tar.gz";
is pkgbuild_uri('bar'), "$pkgs/ba/bar/PKGBUILD";

done_testing;
