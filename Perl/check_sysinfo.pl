#!/usr/bin/perl
#
# check_sysinfo.pl - report on various system stats
#

use strict;

my $debug = 1 ;

my $exitcode = 0 ;
my $os = `uname`;
chomp($os) ;

my $command = shift ;

my @options = @ARGV ;

my %commands =
  (
    "Linux" =>  {
      freemem => "cat /proc/meminfo | grep \"MemFree\" | awk \'{print \$2}\'",
      freeswap => "cat /proc/meminfo | grep \"SwapFree\" | awk \'{print \$2}\'",
      loadavg => "cat /proc/loadavg | awk \'{print \$1}\'",
      uptime => "uptime | awk \'{print \$3}\'",
    },
    "SunOS" =>  {
      freemem => "vmstat | tail -1 | awk \'{print \$5}\'",
      freeswap => "swap -s | awk \'{print \$11}\' | awk -Fk \'{print \$1}\'",
      loadavg => "w | grep load | grep -v grep | awk \'{print \$10}\' | awk -F, \'{print \$1}\'",
      uptime => "uptime | awk \'{print \$3}\'",
    }
  );

my %subroutines =
  (
    "uptime"     => \&uptime,
    "memory"     => \&memory,
    "swap"     => \&swap,
    "load"     => \&load,
    "processes" => \&processes,
  );

if (exists $subroutines{$command}) {
  my $rsub = $subroutines{$command};
  &$rsub(@options);
} else {
  print "$command check unknown\n" ;
  exit(2) ;
}


sub load {
  my $warn = shift ;
  my $critical = shift ;
  my $loadavg = `$commands{$os}{loadavg}` ;
  chomp($loadavg);
  print STDERR "load = $loadavg\n" if ($debug) ;
  if ( $loadavg >= $critical ) {
    print "critical: load average $loadavg\n" ;
    exit(2) ;
  } elsif ( $loadavg >= $warn ) {
    print "warning: load average $loadavg\n" ;
    exit(1) ;
  } elsif ( $loadavg < $warn ) {
    print "ok: load average $loadavg\n" ;
    exit(0) ;
  } else {
    print "critical: unknown load average\n" ;
    exit(2) ;
  }
}

sub uptime{
  my $warn = shift ;
  my $critical = shift ;

  my $updays = `$commands{$os}{uptime}` ;
  chomp($updays) ;
  if ( $updays < $critical ) {
    print "critical: uptime $updays days\n" ;
    exit(2) ;
  } elsif ( $updays < $warn ) {
    print "warning: uptime $updays days\n" ;
    exit(1) ;
  } elsif ( $updays >= $warn ) {
    print "ok: uptime $updays days\n" ;
    exit(0) ;
  } else {
    print "critical: unknown uptime\n" ;
    exit(2) ;
  }
}

sub memory{
  my $warn = shift ;
  my $critical = shift ;

  my $freemem = `$commands{$os}{freemem}` ;
  chomp($freemem) ;
  if ( $freemem < $critical ) {
    print "critical: ${freemem}KB free memory\n" ;
    exit(2) ;
  } elsif ( $freemem < $warn ) {
    print "warning: ${freemem}KB free memory\n" ;
    exit(1) ;
  } elsif ( $freemem >= $warn ) {
    print "ok: ${freemem}KB free memory\n" ;
    exit(0) ;
  } else {
    print "critical: unknown free memory\n" ;
    exit(2) ;
  }
}

sub swap{
  my $warn = shift ;
  my $critical = shift ;

  my $freeswap = `$commands{$os}{freeswap}` ;
  chomp($freeswap) ;
  if ( $freeswap < $critical ) {
    print "critical: ${freeswap}KB free swap\n" ;
    exit(2) ;
  } elsif ( $freeswap < $warn ) {
    print "warning: ${freeswap}KB free swap\n" ;
    exit(1) ;
  } elsif ( $freeswap >= $warn ) {
    print "ok: ${freeswap}KB free swap\n" ;
    exit(0) ;
  } else {
    print "critical: unknown free swap\n" ;
    exit(2) ;
  }
}
