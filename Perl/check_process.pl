#!/usr/bin/perl
#
# check_process.pl - checks various aspects of processes
#
# ecl - 1.0 count and status implemented
#
# todo: add memory and cpu monitoring

use strict ;
use Proc::ProcessTable ;
use Getopt::Long ;

Getopt::Long::Configure ("no_ignore_case") ;

use constant USAGEMSG => <<USAGE;

Usage: check_process.pl -c <check_type> -p <process> [-r] [-d]
Options:
        --check (-c) type of check to perform (status, count)
        --process (-p) name and arguments of process to search for
        --warn (-W) warning level (needed for certain check types)
        --critical (-C) critical level (needed for certain check types)
        --debug (-D) turn on verbose debugging for backup
        --reverse (-r) reverse meaning of warning/critical in count or status

USAGE

my ( $check_type, $command, $warning, $critical, $debug, $reverse ) ;

$reverse = 0 ;

GetOptions("debug|D"      => \$debug,
           "process|p=s"  => \$command,
           "check|c=s"    => \$check_type,
           "critical|C=s" => \$critical,
           "reverse|r"    => \$reverse,
           "warning|W=s"  => \$warning)
      or Getopt::Long::HelpMessage(2);

$command or $check_type or die USAGEMSG ;

my $numprocesses = 0 ;

my $t = new Proc::ProcessTable;

foreach my $p ( @{$t->table} ){
  if ( $p->cmndline =~ /\Q$command\E/ ) {
    unless ( $p->cmndline =~ /\Q$0\E/ ) {
      $numprocesses++ ;
    }
  }
}

if ( $check_type eq "status" ) {

  if (( $numprocesses > 0 ) != $reverse) {

    print "ok: $command ", "not "x$reverse, "running\n" ;
    exit ( 0 ) ;

  } else {

    print "critical: $command ", "not "x(1-$reverse), "running\n" ;
    exit ( 2 ) ;

  }

} elsif ( $check_type eq "count" ) {

  if ( (( $numprocesses > $critical ) != $reverse ) or ( $numprocesses == $critical ) ) {

    print "critical: process count - $command - $numprocesses " ;
    print "above "x(1-$reverse), "below "x$reverse, "threshold $critical\n" ;
    exit ( 2 ) ;

  } elsif ( (( $numprocesses > $warning ) != $reverse ) or ( $numprocesses == $warning ) ) {

    print "warning: process count - $command - $numprocesses " ;
    print "above "x(1-$reverse), "below "x$reverse, "threshold $warning\n" ;
    exit ( 1 ) ;

  } else {

    print "ok: process count - $command - $numprocesses running \n" ;
    exit ( 0 ) ;

  }

} else {

}
