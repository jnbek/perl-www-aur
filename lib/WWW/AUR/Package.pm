package WWW::AUR::Package;

use warnings;
use strict;

use LWP::UserAgent qw();
use Text::Balanced qw(extract_delimited extract_bracketed);
use File::Path     qw(make_path);
use File::Spec     qw();
use WWW::AUR       qw();
use Memoize        qw(memoize);
use Carp           qw();
use Cwd            qw(getcwd);

##############################################################################
# CONSTANTS
#-----------------------------------------------------------------------------

my $AUR_PKGFMT = "$WWW::AUR::BASEURI/packages/%s/%s.tar.gz";
my $AUR_PBFMT  = "$WWW::AUR::BASEURI/packages/%s/%s/PKGBUILD";
my $PKGURI     = "$WWW::AUR::BASEURI/packages.php";
my $PKGGETFMT  = "$PKGURI?ID=%d";

my $MAINTAINER_MATCH = qr{ <span [ ] class='f3'>
                           Maintainer: \s+ ( [^<]+ )
                           </span> }xms;

#---CONSTRUCTOR---
sub new
{
    my $class = shift;

    Carp::croak( "You must at least supply a name as argument" ) if @_ == 0;
    my $name   = shift;
    my %params = @_;

    my %obj;
    if ( ! defined $params{info} ) {
        %obj = eval { WWW::AUR->info( $name ) }
            or Carp::croak( "Failed to find package: $name" );
    }
    else { %obj = %{ $params{info} }; }

    my $base = $params{basepath};
    unless ( ( $params{dlpath} && $params{extpath} && $params{destpath} )
             || $base ) {
        $base = $WWW::AUR::BASEPATH;
    }

    $obj{ dlpath   } = $params{dlpath}   || "$base/src";
    $obj{ extpath  } = $params{extpath}  || "$base/build";
    $obj{ destpath } = $params{destpath} || "$base/cache";
    $obj{ pkgfile  } = "$name.src.tar.gz";
    $obj{ name     } = $name;
    
    bless \%obj, $class;
}

#---PRIVATE METHOD---
sub _download_url
{
    my ($self) = @_;
    return sprintf $AUR_PKGFMT, $self->{name}, $self->{name};
}

#---OBJECT METHOD---
sub download_size
{
    my ($self) = @_;

    my $ua   = LWP::UserAgent->new( agent => $WWW::AUR::USERAGENT );
    my $resp = $ua->head( $self->_download_url() );
    
    return undef unless $resp->is_success;
    return $resp->header( 'content-length' );
}
memoize( 'download_size' );

#---OBJECT METHOD---
sub download
{
    my ($self, $usercb) = @_;

    my $pkgurl  = $self->_download_url();
    my $pkgpath = "$self->{dlpath}/$self->{pkgfile}";

    make_path( $self->{dlpath} );

    open my $pkgfile, '>', $pkgpath or die "Failed to open $pkgpath:\n$!";
    binmode $pkgfile;

    my $store_chunk = sub {
        my $chunk = shift;
        print $pkgfile $chunk;
    };

    if ( $usercb ) {
        my $total = $self->download_size();
        my $dled  = 0;

        my $store = $store_chunk;
        $store_chunk = sub {
            my $chunk = shift;
            $dled += length $chunk;
            $usercb->( $dled, $total );
            $store->( $chunk );
        };
    }

    my $ua   = LWP::UserAgent->new( agent => $WWW::AUR::USERAGENT );
    my $resp = $ua->get( $self->_download_url(),
                         ':content_cb' => $store_chunk );

    close $pkgfile or die "close: $!";

    Carp::croak( 'Failed to download package file:' . $resp->status_line )
        unless $resp->is_success;

    $self->{srcpkg_path} = $pkgpath;
    return $pkgpath;
}

#---OBJECT METHOD---
sub extract
{
    my ($self) = @_;

    my $pkgpath = $self->src_pkg_path || $self->download();
    my $destdir = $self->{dlpath};

    make_path( $destdir );

    my $retval = system "bsdtar -zx -f $pkgpath -C $destdir";
    die "failed to extract source packge with bsdtar:\n$!"
        unless $retval == 0;

    my $srcpkg_dir = File::Spec->catdir( $destdir, $self->{name} );
    return $self->{srcpkg_dir} = $srcpkg_dir;
}

#---OBJECT METHOD---
sub src_pkg_path
{
    my ($self) = @_;
    return $self->{srcpkg_path};
}

#---OBJECT METHOD---
sub src_dir_path
{
    my ($self) = @_;
    return $self->{srcpkg_dir};
}

#---PUBLIC METHOD---
sub make_src_path
{
    my ($self, $relpath) = @_;
    
    Carp::croak 'You must call extract() before srcdir_file()'
        unless $self->{srcpkg_dir};

    $relpath =~ s{\A/+}{};
    return $self->{srcpkg_dir} . q{/} . $relpath;
}

#---HELPER FUNCTION---
sub _unquote_bash
{
    my ($bashtext) = @_;
    my $elem;

    # Extract the values of a bash array...
    if ( $bashtext =~ s/ \A [(] ([^)]*) [)] (.*) \z /$1/xms ) {
        my ( $arrtext, @result );

        ( $arrtext, $bashtext ) = ( $1, $2 );
        while ( length $arrtext ) {
            ( $elem, $arrtext ) = _unquote_bash( $arrtext );
            $arrtext =~ s/ \A \s+ //xms;
            push @result, $elem;
        }

        return ( \@result, $bashtext );
    }

    # Single quoted strings cannot escape the quote (')...
    if ( $bashtext =~ / \A ' (.+?) ' (.*) \z /xms ) {
        ( $elem, $bashtext ) = ( $1, $2 );
    }
    # Double quoted strings can...
    elsif ( substr $bashtext, 0, 1 eq q{"} ) {
        ( $elem, $bashtext ) = extract_delimited( $bashtext, q{"} );
    }
    # Otherwise regular words are treated as one element...
    else {
        ( $elem, $bashtext ) = $bashtext =~ / \A (\S+) (.+) \z /xms;
    }

    return ( $elem, $bashtext );
}

#---HELPER FUNCTION---
sub _depstr_to_hash
{
    my ($depstr) = @_;
    my ($pkg, $cmp, $ver) = $depstr =~ / \A ([\w_-]+)
                                         (?: ([=<>]=?)
                                             ([\w._-]+) )? \z/xms;

    Carp::croak "Failed to parse depend string: $_" unless $pkg;

    $cmp ||= q{>};
    $ver ||= 0;
    return +{ 'pkg' => $pkg, 'cmp' => $cmp,
              'ver' => $ver, 'str' => $depstr };
}

#---HELPER FUNCTION---
sub _pkgbuild_fields
{
    my ($pbtext) = @_;

    my %pbfields;
    while ( $pbtext =~ / ^ (\w+) = /xmsg ) { 
        my $name = $1;
        my $value;

        # printf STDERR "DEBUG: \$name = $name -- pos = %d\n", pos $pbtext;
        # printf STDERR "DEBUG: %s\n", substr $pbtext, 0, 70;
        $pbtext = substr $pbtext, pos $pbtext;
        ( $value, $pbtext ) = _unquote_bash( $pbtext );
        # print STDERR "DEBUG: \$value = $value\n";

        $pbfields{ $name } = $value;
    }

    for my $depkey ( qw/ depends conflicts / ) {
        my @fixed;

        @fixed = map { _depstr_to_hash($_) } @{$pbfields{ $depkey }}
            if $pbfields{ $depkey };

        $pbfields{ $depkey } = \@fixed;
    }
    
    return %pbfields;
}

#---PRIVATE METHOD---
sub _parse_pkgbuild
{
    my ($self, $pbtext) = @_;

    my %pbfields = _pkgbuild_fields( $pbtext );
    return $self->{pkgbuild} = \%pbfields;
}

#---PRIVATE METHOD---
sub _extracted_pkgbuild
{
    my ($self) = @_;
    my $pbpath = $self->make_src_path( 'PKGBUILD' );
    open my $pbfile, '<', $pbpath or die "open: $!";
    my $pbtext = do { local $/; <$pbfile> };
    close $pbfile;
    return $pbtext;
}

#---PRIVATE METHOD---
# Purpose: Download the package's PKGBUILD without saving it to a file.
sub _download_pkgbuild
{
    my ($self) = @_;

    my $name = $self->{name};
    my $pkgbuild_url = sprintf $AUR_PBFMT, $name, $name;

    my $ua   = LWP::UserAgent->new( agent => $WWW::AUR::USERAGENT );
    my $resp = $ua->get( $pkgbuild_url );
    
    Carp::croak "Failed to download ${name}'s PKGBUILD: "
        . $resp->status_line() unless $resp->is_success();

    return $resp->content();
}

#---PUBLIC METHOD---
sub pkgbuild
{
    my ($self) = @_;

    return $self->{pkgbuild}
        if $self->{pkgbuild};
    
    my $pbtext = ( $self->{srcpkg_dir}
                   ? $self->_extracted_pkgbuild()
                   : $self->_download_pkgbuild() );
    return $self->_parse_pkgbuild( $pbtext );
}

#---PRIVATE METHOD---
sub _builtpkg_path
{
    my ($self, $pkgdest) = @_;
    my $pkgbuild    = $self->pkgbuild;
    my $arch        = $pkgbuild->{arch};

    if ( eval { $arch->[0] eq 'any' } ) {
        $arch = 'any';
    }

    unless ( $arch eq 'any' ) {
        $arch = `uname -m`;
        chomp $arch;
    }

    my $pkgfile = sprintf '%s-%s-%d-%s.pkg.tar.xz',
        $self->{name}, $pkgbuild->{pkgver}, $pkgbuild->{pkgrel}, $arch;
    return File::Spec->catfile( $pkgdest, $pkgfile );
}

#---PUBLIC METHOD---
sub build
{
    my ($self, %params) = @_;

    return $self->{builtpkg_path}
        if $self->{builtpkg_path};

    my $srcdir  = $self->src_dir_path || $self->extract();
    my $pkgdest = $params{ pkgdest };
    if ( $pkgdest ) { $pkgdest =~ s{/+\z}{};        }
    else            { $pkgdest = $self->{destpath}; }
    $pkgdest = File::Spec->rel2abs( $pkgdest );

    make_path( $pkgdest );
    my $oldcwd = getcwd();
    chdir $srcdir;

    my $cmd = 'makepkg -f';
    $cmd = "$params{prefix} $cmd" if $params{prefix};
    $cmd = "$cmd $params{args}"   if $params{args};

    if ( $params{quiet} ) { $cmd .= ' 2>&1 >/dev/null'; }
 
    local $ENV{PKGDEST} = $pkgdest;
    ( system $cmd ) == 0
        or Carp::croak "makepkg failed to run: $?";

    chdir $oldcwd;

    my $built_path = $self->_builtpkg_path( $pkgdest );
    Carp::croak 'makepkg succeeded but the package file is missing'
        unless -f $built_path;
    return $self->{builtpkg_path} = $built_path;
}

sub bin_pkg_path
{
    my ($self) = @_;
    return $self->{builtpkg_path};
}

#---PUBLIC METHOD---
# Purpose: Scrape the package webpage to get the maintainer's name
sub maintainer
{
    my ($self) = @_;

    my $uri = sprintf $PKGGETFMT, $self->{id};
    my $ua  = LWP::UserAgent->new( agent => $WWW::AUR::USERAGENT );
    my $req = $ua->get( $uri );

    Carp::croak qq{Failed to load webpage for the "$self->{name}" package:\n}
        . $req->status_line unless $req->is_success;

    my ($username) = $req->content =~ /$MAINTAINER_MATCH/xms;
    Carp::croak qq{Failed to scrape package webpage for maintainer}
        unless $username;

    # Orphaned packages don't have a maintainer...
    return undef if $username eq 'None';

    # Propogate parameters to our new Maintainer object...
    my %params = WWW::AUR::_path_params( $self );
    my $m_obj  = WWW::AUR::Maintainer->new( $username, %params );

    return $m_obj;
}

1;

__END__
