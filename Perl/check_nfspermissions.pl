#!/usr/bin/perl
#
# See LICENSE for copyright information
#
# check_nfsmount.pl <host> <mount point|mount device> [mount-option1/mount-option2/...] [port]
#
# NetSaint host script to get the disk usage from a client that is running
# netsaint_statd.
#

require 5.003;
BEGIN { $ENV{PATH} = '/bin' }
use Socket;
use POSIX;
use strict;

sub usage;

my $debug = 1;

my $TIMEOUT = 15;

my %ERRORS = ('UNKNOWN', '-1',
		'OK', '0',
		'WARNING', '1',
		'CRITICAL', '2');

my $remote    = shift || &usage(%ERRORS);
my $mount     = shift || &usage(%ERRORS);
my $mountopts = shift || "read";
my $port      = shift || 1040;

print "DEBUG: Mount: $mount, Mountopts: $mountopts, Port: $port\n\n" if $debug;

my $remoteaddr = inet_aton("$remote");
my $paddr = sockaddr_in($port, $remoteaddr) || die "Can't create info for connection: #!\n";;
my $proto = getprotobyname('tcp');
socket(Server, PF_INET, SOCK_STREAM, $proto) || die "Can't create socket: $!";
setsockopt(Server, SOL_SOCKET, SO_REUSEADDR, 1);
connect(Server, $paddr) || die "Can't connect to server: $!";

my $state   = "OK";
my $answer  = undef;
my $mntans  = undef;
my $mntopt  = undef;
my $usethis = undef;
my $mntsep  = undef;
my $mntsep2 = undef;
my $mntgrep = undef;
my $mntrw   = undef;
my @servermountoptions = undef;
my $mntwritestr = "mounted as writeable but file-write operation failed";
my $grepnot = 0;
my %mountopts = (	"ro"		=> "^write",
			"^ro"		=> "write",
			"readonly"	=> "^write",
			"rw"		=> "write",
			"^rw"		=> "^write",
		);

# Just in case of problems, let's not hang NetSaint
$SIG{'ALRM'} = sub { 
        close(Server);
        select(STDOUT);
	print "No Answer from Client\n";
	exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);

select(Server);
$| = 1;

print Server "nfs $mount\n";
my ($servanswer) = <Server>;
alarm(0);
close(Server);

select(STDOUT);

# default to CRITICAL/Not mounted until proven otherwise
$state = "CRITICAL";
$answer = "Not mounted\n";

print "DEBUG: nfs: $mount, server answer: XX${servanswer}XX\n\n" if $debug;

if ($servanswer =~ /^([\w\/,\d\.\:\-\=]*) on ([\w\/,\d\.\:\-\=]*) ([\w\/,\d\.\:\-\= ]*) (\d*) (\d*) writecheck([\w]*)$/)
	{
	my ($mountpoint)   = $1;
	my ($mountdevice)  = $2;
	my ($mountoptions) = $3;
	my ($avail) = $4;
	my ($capper) = $5;
	my ($writecheck) = $6;

	print "DEBUG: mountpoint: $1, mountdevice: $2, mountoptions: $3, avail: $4, capper $5, writecheck $6\n\n" if $debug;
	if ($mount eq $mountpoint || $mount eq $mountdevice)
		{
		$state = "OK";
		$mntrw = "";
		if(grep(/\bread only\b/i, $mountoptions))
			{
			$mntrw = "read only";
			}
		elsif (grep(/\bwrite\b/i, $mountoptions) && grep(/\bread\b/i, $mountoptions))
			{
			$mntrw = "read/write";
			}
		elsif (grep(/\bread\b/i, $mountoptions))
			{
			$mntrw = "read";
			}
		$answer = "$mountpoint mounted $mntrw on $mountdevice";
		if (int($avail / 1024) > 0)
			{
			$avail = int($avail / 1024);
			if (int($avail /1024) > 0)
				{
				$avail = (int(($avail / 1024)*100))/100;
				$avail = $avail."G";
				}
			else
				{
				$avail = $avail."M";
				}
			}
		else
			{
			$avail = $avail."K";
			}
		@servermountoptions = split('/',$mountoptions);
		$mntsep = $mntsep2 = "";
		foreach $mntopt (split('/',$mountopts))
			{
			$usethis = $mountopts{$mntopt} ? $mountopts{$mntopt} : $mntopt;
			if ($usethis =~ /^\^(.*)$/)
				{
				$grepnot = 1;
				$usethis = $1;
				}
			else
				{
				$grepnot = 0;
				}
			$mntgrep = grep(/\b$usethis\b/i, @servermountoptions);
			$mntsep = ($mntans eq "" ? "" : " and ");
			$mntsep2 = ($mntopt =~ /^\^/ ? "should not be" : "should be");
			$mntopt = ($mntopt =~ /^\^(.*)$/ ? $1 : $mntopt);
			$mntopt = "writeable" if $mntopt eq "write";
			$mntopt = "readable" if $mntopt eq "read";
			if (!$mntgrep && !$grepnot)
				{
				$state="CRITICAL";
				$mntans .= $mntsep . "$mntsep2 $mntopt";
				}
			if ($mntgrep && $grepnot)
				{
				$state="CRITICAL";
				$mntans .= $mntsep . "$mntsep2 $mntopt";
				}
			print "DEBUG: mountoption: $usethis checking in $mountoptions\n\n" if $debug;
			print "DEBUG: grep output: XX", grep(/\b$usethis\b/i,@servermountoptions), "XX\n\n" if $debug;
			}
		}
		#11/1/04, commented out
		#if($writecheck eq "fail")
		#{
		#		$state="CRITICAL";
		#		$mntans  = ($mntans eq "" ? $mntwritestr : $mntans . " and $mntwritestr");
		#}
		$answer .= " (" . $mntans . "!)" if $mntans;
		$answer .= "\n";
	}
elsif ($servanswer eq "not found")
	{
	$state = "CRITICAL";
	$answer = "NFS $mount not mounted or nonexistant\n";
	}
else
	{
	$state = "UNKNOWN";
	$answer = "Unknown status on NFS $mount\n";
	}

print "DEBUG: Answer: $answer, State: $state\n\n" if $debug;

print $answer;
exit $ERRORS{$state};

sub usage {
	print "Minimum arguments not supplied!\n";
	print "\n";
	print "Perl Check NFS Mount plugin for NetSaint\n";
	print "Copyright (c) 1999 Charlie Cook\n";
	print "Modified for NFS checks - NE Jul 2003\n";
	print "\n";
	print "Usage: $0 <host> <mount point|mount device> [<mount-option1/mount-option2/...> [<port>]]]\n";
	print "\n";
	print "<mount-option1...> = Mount options to check, separated by \/.\n	Defaults to \"read\".\n";
        print "<port> = Port that the status daemon is running on <host>.\n	Defaults to 1040.\n";
	exit $ERRORS{"UNKNOWN"};
}

