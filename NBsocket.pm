#!/usr/bin/perl

package Net::NBsocket;
use strict;
#use diagnostics;

use vars qw(
	$VERSION @ISA @EXPORT_OK *UDP *TCP
);
use POSIX;
use Socket;
use AutoLoader 'AUTOLOAD';
require Exporter;
@ISA = qw(Exporter);

$VERSION = do { my @r = (q$Revision: 0.04 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

@EXPORT_OK = qw(
        open_udpNB
	open_listenNB
	connect_NB
	accept_NB
	set_NB
	set_so_linger
);

# used a lot, create once per session
*UDP = \getprotobyname('udp');
*TCP = \getprotobyname('tcp');

sub DESTROY {};

1;
__END__

=head1 NAME

Net::NBsocket -- Non-Blocking Sockets

=head1 SYNOPSIS

  use Net::NBsocket qw(
        open_udpNB
	open_listenNB
	connect_NB
	accept_NB
	set_NB
	set_so_linger
  );

  $sock = open_udpNB();
  $listener = open_listenNB($port_path,$netaddr);
  $rv = set_sockNB(*SOCK);
  $rv = set_so_linger(*HANDLE,$seconds);
  $client = connect_NB($port_path,$netaddr);
  ($sock,$netaddr) = accept_NB(*SERVER);
    

=head1 DESCRIPTION

B<Net::DNSBL::Utilities> contains functions used to build DNSBL
emulator daemons.

=over 4

=item * $sock = open_udpNB();

Open and return a non-blocking UDP socket object

  input:	none
  returns:	pointer to socket object
		or undef on failure

=cut

sub open_udpNB {
  my $flags;
  local *USOCK;
  return undef unless socket(USOCK,PF_INET,SOCK_DGRAM,$UDP);
  return *USOCK if set_NB(*USOCK);
  close USOCK;
  return undef;
}

=item * $listener = open_listenNB($port_path);

Open and return a non-blocking TCP listener bound to $port_path and an
optional IPv4 bind address as returned by inet_aton 
(defaults to INADDR_ANY).

Opens a unix-domain socket if port_path is a path instead of a number.

The user must set the appropriate UMASK prior to calling this routine.

  input:	port or unix domain socket path,
		[optional] bind address
  returns:	pointer to listening socket
		object or undef on failure

=cut

sub open_listenNB {
  my ($port_path,$addr) = @_;;
  local *LSOCK;
  $addr = INADDR_ANY unless $addr;

  my $path = ($port_path =~ /\D/) ? $port_path : undef;
  if ($path) {
    return undef unless socket(LSOCK,PF_UNIX,SOCK_STREAM,0);
  } else {
    return undef unless socket(LSOCK,PF_INET,SOCK_STREAM,$TCP);
  }
  my $ok = setsockopt(LSOCK,SOL_SOCKET,SO_REUSEADDR,pack("l", 1));
  if ($path) {
    unlink $path if -e $path && -S $path;
    ($ok = bind(LSOCK,sockaddr_un($path))) if $ok;
  } else {
    ($ok = bind(LSOCK,sockaddr_in($port_path,$addr))) if $ok;
  }
  return *LSOCK if $ok &&
	listen(LSOCK,SOMAXCONN) &&
	set_NB(*LSOCK);
  close LSOCK;
  return undef;
}

=item * $rv = set_sockNB(*SOCK);

Set a socket to Non-Blocking mode

  input:	SOCK object pointer
  returns:	true on success or
		undef on failure

=cut

sub set_NB {
  my $sock = shift;
  my $flags = fcntl($sock,F_GETFL(),0);
  fcntl($sock,F_SETFL(),$flags | O_NONBLOCK())
}

=item $rv = set_so_linger(*HANDLE,$seconds);

  Set SO_LINGER on top level socket

  input:        *HANDLE, seconds
  returns:      true = success, false = fail

=cut

sub set_so_linger {
  my ($FH,$sec) = @_;
  setsockopt($FH,SOL_SOCKET,SO_LINGER,pack("ll",1,$sec));
}

=item * $client = connect_NB($port_path,$netaddr);

Begin a non-blocking TCP connection to the host designated by $netaddr on
$port_path, or to the unix domain socket designated by the path in $port_path.
$netaddr is unused for unix domain sockets.


  input:	port number or unix domain socket path,
		netaddr as returned by inet_aton
  returns:	socket object or
		undef on failure

=cut

sub connect_NB {
  my($port_path,$netaddr) = @_;
  local *CSOCK;
  my $daddr;
  if ($port_path =~ /\D/) {
    $daddr = sockaddr_un($port_path);
    return undef unless $daddr && socket(CSOCK,PF_UNIX,SOCK_STREAM,0);
  } else {
    $daddr = sockaddr_in($port_path,$netaddr);
    return undef unless $daddr && socket(CSOCK,PF_INET,SOCK_STREAM,$TCP);
  }
  if (set_NB(*CSOCK)) {
    return *CSOCK if connect(CSOCK,$daddr) || $! == EINPROGRESS;
  }
  close CSOCK;
  return undef;
}

=item * ($sock,$netaddr) = accept_NB(*SERVER);

Accept a connection from a remote client, return a non-blocking socket
and the network address of the remote host as returned by inet_aton or
the unix domain socket path if PF_INET or PF_UNIX respectively.

  input:	listening socket object
  returns:	client socket object,
		client packed netaddr or
		unix domain socket path
		or an emtpy array on failure

=back

=cut

sub accept_NB {
  my $server = shift;
  local *CLONE;
  my $paddr = accept(CLONE,$server);
  return () unless $paddr;		# attempted accept with no client
  my($port_path,$netaddr) = eval {sockaddr_in($paddr)};
  if ($@) {
    $netaddr = sockaddr_un($paddr);
  }
  return (*CLONE,$netaddr)
	if $paddr && $netaddr && set_NB(*CLONE);
  close CLONE;
  return ();
}

=head1 DEPENDENCIES

	POSIX
	Socket

=head1 EXPORT_OK

        open_udpNB
	open_listenNB
	connect_NB
	accept_NB
	set_NB
	set_so_linger

=head1 AUTHOR

Michael Robinton, michael@bizsystems.com

=head1 COPYRIGHT

Copyright 2004, Michael Robinton & BizSystems
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or 
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of 
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the  
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

=cut

1;
