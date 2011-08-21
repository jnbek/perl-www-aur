package WWW::AUR::RPC;

use warnings 'FATAL' => 'all';
use strict;

use JSON qw();
use Carp qw();

use WWW::AUR::UserAgent qw();
use WWW::AUR::URI       qw( rpc_uri );
use WWW::AUR            qw( _category_name );

my %_RENAME_FOR = ( 'Description' => 'desc',
                    'NumVotes'    => 'votes',
                    'CategoryID'  => 'category',
                    'LocationID'  => 'location',
                    'OutOfDate'   => 'outdated',
                   );

#---HELPER FUNCTION---
# Purpose: Map JSON package info keys to their new names...
sub _rpc_pretty_pkginfo
{
    my ($info_ref) = @_;

    my %result;
    for my $key ( keys %$info_ref ) {
        my $newkey         = $_RENAME_FOR{ $key } || lc $key;
        $result{ $newkey } = $info_ref->{ $key };
    }

    $result{category} = _category_name( $result{category} );

    return \%result;
}

#---CLASS/OBJECT METHOD---
sub info
{
    my ($name) = @_;

    my $uri     = rpc_uri( "info", $name );
    my $ua      = WWW::AUR::UserAgent->new;
    my $resp    = $ua->get( $uri );

    Carp::croak 'Failed to call info AUR RPC: ' . $resp->status_line
        unless $resp->is_success;

    my $json = JSON->new;
    my $data = $json->decode( $resp->content );

    if ( $data->{type} eq "error" ) {
        return () if $data->{results} eq 'No results found';
        Carp::croak "Remote error: $data->{results}";
    }

    return %{ _rpc_pretty_pkginfo( $data->{results} ) };
}

sub minfo
{
    my (@names) = @_;

    my $uri     = rpc_uri( "minfo", @names );
    my $ua      = WWW::AUR::UserAgent->new;
    my $resp    = $ua->get( $uri );

    Carp::croak 'Failed to call minfo AUR RPC: ' . $resp->status_line
        unless $resp->is_success;

    my $json = JSON->new;
    my $data = $json->decode( $resp->content );

    if ( $data->{type} eq "error" ) {
        return () if $data->{results} eq 'No results found';
        Carp::croak "Remote error: $data->{results}";
    }

    return map { _rpc_pretty_pkginfo($_) } @{$data->{results}};
}

sub search
{
    my ($query) = @_;

    my $regexp;
    if ( $query =~ /\A\^/ || $query =~ /\$\z/ ) {
        $regexp = eval { qr/$query/ };
        if ( $@ ) {
            Carp::croak qq{Failed to compile "$query" into regexp:\n$@};
        }

        $query  =~ s/\A\^//;
        $query  =~ s/\$\z//;
    }

    my $uri  = rpc_uri( 'search', $query );
    my $ua   = WWW::AUR::UserAgent->new();
    my $resp = $ua->get( $uri );
    Carp::croak 'Failed to search AUR using RPC: ' . $resp->status_line
        unless $resp->is_success;

    my $json = JSON->new;
    my $data = $json->decode( $resp->content )
        or die 'Failed to decode the search AUR json request';

    if ( $data->{type} eq 'error' ) {
        return [] if $data->{results} eq 'No results found';
        Carp::croak "Remote error: $data->{results}";
    }

    my $results = [ map { _rpc_pretty_pkginfo( $_ ) } @{ $data->{results} } ];

    if ( $regexp ) {
        $results = [ grep { $_->{name} =~ /$regexp/ } @$results ];
    }

    return $results;
}

sub msearch
{
    my ($name) = @_;

    my $aururi = rpc_uri( 'msearch', $name );
    my $ua     = WWW::AUR::UserAgent->new();
    my $resp   = $ua->get( $aururi );
    Carp::croak qq{Failed to lookup maintainer using RPC:\n}
        . $resp->status_code unless $resp->is_success;

    my $json     = JSON->new;
    my $json_ref = $json->decode( $resp->content );

    if ( $json_ref->{type} eq 'error' ) {
        return [] if $json_ref->{results} eq 'No results found';
        Carp::croak "Remote error: $json_ref->{results}";        
    }

    return [ map { _rpc_pretty_pkginfo( $_ ) } @{ $json_ref->{results} } ];
}

1;
