package WWW::AUR;

use warnings;
use strict;

use LWP::Simple qw();
use JSON        qw();
use Carp        qw();

use WWW::AUR::URI;
use WWW::AUR::Var;
use WWW::AUR::RPC;
use WWW::AUR::Package;

our $VERSION   = $VERSION;

my %_IS_AUR_FIELD = map { ( $_ => 1 ) } qw/ basepath buildpath pkgpath /;
sub new
{
    my $class  = shift;
    my %params = @_;

    for my $key ( keys %params ) {
        Carp::croak "Invalid constructor parameter: $key"
            unless $_IS_AUR_FIELD{ $key };
    }

    $params{ basepath } ||= $BASEPATH;

    return bless \%params, $class
}

#---PRIVATE METHOD---
# Purpose: Extract path parameters if we are an object
sub _path_params
{
    my ($self) = @_;

    my %params;
    for my $key ( qw/ basepath dlpath extpath destpath / ) {
        $params{ $key } = $self->{ $key };
    }

    return %params;
}

sub search
{
    my ($self, $query) = @_;
    my $found_ref = WWW::AUR::RPC::search( $query );

    my %params = $self->_path_params;
    return [ map {
        WWW::AUR::Package->new( $_->{name}, info => $_, %params );
    } @$found_ref ];
}

sub find
{
    my ($self, $name) = @_;

    my %params = $self->_path_params;
    return eval { WWW::AUR::Package->new( $name, %params ) };
}

sub maintainer
{
    my ($self, $name) = @_;

    my %params = $self->_path_params;
    return eval { WWW::AUR::Maintainer->new( $name, %params ) };
}

1;

__END__

=head1 NAME

WWW::AUR - API for the Archlinux User Repository website.

=head1 SYNOPSIS

=head1 DESCRIPTION

This module provides an interface for the straight-forward AUR user
as well as an AUR author, or package maintainer.

=head1 AUTHOR

Justin Davis, C<< <juster at cpan dot org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-aur at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-AUR>.  I will be
notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

Read the manual first.  Send me an email if you still need help.

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Justin Davis.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut
