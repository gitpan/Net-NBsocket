#!/usr/bin/perl

package Net::NBsocket;
use strict;
use diagnostics;

use vars qw(
	$VERSION @ISA @EXPORT_OK $UDP $TCP
);
use POSIX;
use Socket;
#use AutoLoader 'AUTOLOAD';
require Exporter;
@ISA = qw(Exporter);

$VERSION = do { my @r = (q$Revision: 0.08 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

@EXPORT_OK = qw(
	open_UDP
	open_udpNB
	bind2pp
	open_Listen
	open_listenNB
	connect_NB
	accept_Blk
	accept_NB
	set_NB
	set_so_linger
	inet_aton
	inet_ntoa
	sockaddr_in
	sockaddr_un
);

# used a lot, create once per session
$UDP = getprotobyname('udp');
$TCP = getprotobyname('tcp');

sub DESTROY {};

#1;
#__END__

=head1 NAME

Net::NBsocket -- Non-Blocking Sockets

=head1 SYNOPSIS

  use Net::NBsocket qw(
	open_UDP
	open_udpNB
	bind2pp
	open_Listen
	open_listenNB
	connectBlk
	connect_NB
	accept_Blk
	accept_NB
	set_NB
	set_so_linger
	inet_aton
	inet_ntoa
	sockaddr_in
	sockaddr_un
  );

  $sock = open_UDP();
  $sock = open_udpNB();
  $sock = bind2pp($sock,$port_path,$netaddr);
  $listener = open_Listen($port_path,$netaddr);
  $listener = open_listenNB($port_path,$netaddr);
  $rv = set_NB(*SOCK);
  $rv = set_so_linger(*HANDLE,$seconds);
  $client = connectBlk($port_path,$netaddr);
  $client = connect_NB($port_path,$netaddr);
  ($sock,$netaddr) = accept_Blk(*SERVER);
  ($sock,$netaddr) = accept_NB(*SERVER);
  $netaddr = inet_aton($dot_quad);
  $dot_quad = inet_ntoa($netaddr);
  $sin = sockaddr_in($port,$netaddr);
  ($port,$netaddr) = sockaddr_in($sin);
  $sun = sockaddr_un($path);
  ($path) = sockaddr_un($sun);

=head1 DESCRIPTION

B<Net::NBsocket> provides a wrapper for B<Socket> to supply Non-Blocking
sockets of various flavors;

=over 4

=item * $netaddr = inet_aton($dot_quad);

=item * $dot_quad = inet_ntoa($netaddr);

=item * $sin = sockaddr_in($port,$netaddr);

=item * ($port,$netaddr) = sockaddr_in($sin);

=item * $sun = sockaddr_un($path);

=item * ($path) = sockaddr_un($sun);

All above exported from B<Socket> in the EXPORT_OK array.

=item * $sock = open_UDP();

Open an unbound UDP socket as below.

=item * $sock = open_udpNB();

Open and return an unbound  non-blocking UDP socket object

  input:	none
  returns:	pointer to socket object
		or undef on failure

=cut

sub open_UDP {
  local *USOCK;
  return *USOCK if socket(USOCK,PF_INET,SOCK_DGRAM,$UDP);
  close USOCK if scalar *USOCK;
  return undef;
}

sub open_udpNB {
  local *USOCK;
  return *USOCK if socket(USOCK,PF_INET,SOCK_DGRAM,$UDP) && set_NB(*USOCK);
  close USOCK if scalar *USOCK;
  return undef;
}

=item * $sock = bind2pp($sock,$port_path,$netaddr);

Bind to $port_path and an optional IPv4 bind address as returned by inet_aton
(defaults to INADDR_ANY).

  input:	port or unix domain socket path,
		[optional] bind address
  returns:	socket on sucess, else undef;

=cut

sub bind2pp {
  my ($sock,$port_path,$addr) = @_;;
  $addr = INADDR_ANY unless $addr;
  my $path = ($port_path && $port_path =~ /[\D\s]/) ? $port_path : undef;
  my $ok;
  if ($path) {
    unlink $path if -e $path && -S $path;
    $ok = bind($sock,sockaddr_un($path));
  } else {
    $ok = bind($sock,sockaddr_in($port_path,$addr));
  }
  return $sock if $ok;
  close $sock;
  return undef;
}

=item * $listener = open_Listen($port_path,$netaddr);

Open a blocking TCP listner as below.

=item * $listener = open_listenNB($port_path,$netaddr);

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

sub open_Listen {
  my ($port_path,$addr) = @_;;
  local *LSOCK;
  if ($port_path && $port_path =~ /[\D\s]/) {
    return undef unless socket(LSOCK,PF_UNIX,SOCK_STREAM,0);
  } else {
    return undef unless socket(LSOCK,PF_INET,SOCK_STREAM,$TCP);
  }
  my $sockok = setsockopt(LSOCK,SOL_SOCKET,SO_REUSEADDR,pack("l", 1));
# function returns LSOCK if success
  $sockok = bind2pp(*LSOCK,$port_path,$addr) if $sockok;
  return $sockok if $sockok &&
        listen($sockok,SOMAXCONN);
  close $sockok;
  return undef;
}

sub open_listenNB {
  my $lsock = &open_Listen;
  return $lsock if $lsock && set_NB($lsock);
  close $lsock if $lsock;
  return undef;
}

=item * $rv = set_NB(*SOCK);

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

=item * $client = connectBlk($port_path,$netaddr);

Begin a blocking TCP connection as below.

=item * $client = connect_NB($port_path,$netaddr);

Begin a non-blocking TCP connection to the host designated by $netaddr on
$port_path, or to the unix domain socket designated by the path in $port_path.
$netaddr is unused for unix domain sockets.


  input:	port number or unix domain socket path,
		netaddr as returned by inet_aton
  returns:	socket object or
		undef on failure

=cut

sub connectBlk {
  unshift @_,1;
  goto &_connect;
}

sub  connect_NB {
  unshift @_,0;
  goto &_connect;
}

sub _connect {
  my($block,$port_path,$netaddr) = @_;
  local *CSOCK;
  my $daddr;
  if ($port_path =~ /\D/) {
    $daddr = sockaddr_un($port_path);
    return undef unless $daddr && socket(CSOCK,PF_UNIX,SOCK_STREAM,0);
  } else {
    $daddr = sockaddr_in($port_path,$netaddr);
    return undef unless $daddr && socket(CSOCK,PF_INET,SOCK_STREAM,$TCP);
  }
  if ($block || set_NB(*CSOCK)) {
    return *CSOCK if connect(CSOCK,$daddr) || $! == EINPROGRESS;
  }
  close CSOCK;
  return undef;
}

=item * ($sock,$netaddr) = accept_Blk(*SERVER);

Accept a connection and return a BLOCKING socket as below.

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
  unshift @_,0;
  goto &_accept;
}

sub accept_Blk {
  unshift @_,1;
  goto &_accept;
}

sub _accept {
  my($block,$server) = @_;
  local *CLONE;
  my $paddr = accept(CLONE,$server);
  return () unless $paddr;		# attempted accept with no client
  my($port_path,$netaddr) = eval {sockaddr_in($paddr)};
  if ($@) {
    $netaddr = sockaddr_un($paddr);
  }
  return (*CLONE,$netaddr)
	if $paddr && $netaddr && ($block || set_NB(*CLONE));
  close CLONE;
  return ();
}

=head1 DEPENDENCIES

	POSIX
	Socket

=head1 EXPORT_OK

	open_UDP
        open_udpNB
	bind2pp
	open_Listen
	open_listenNB
	connectBlk
	connect_NB
	accept_Blk
	accept_NB
	set_NB
	set_so_linger
	inet_aton
	inet_ntoa
	sockaddr_in
	sockaddr_un

=head1 AUTHOR

Michael Robinton, michael@bizsystems.com

=head1 COPYRIGHT

Copyright 2004 - 2006, Michael Robinton & BizSystems
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

=head1 SEE ALSO

L<POSIX>, L<Socket>

=cut

1;
