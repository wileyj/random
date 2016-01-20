#!/usr/bin/perl
#
# check_mount.pl - checks various aspects of mountpoints
#
# usage: check_mount.pl [check_type] [options]
#

use strict;

my $debug = 0 ;

my $check_type = shift ;

my $hostname = `hostname` ;
chomp($hostname) ;

my @options = @ARGV ;

print "$check_type @options\n" if ($debug) ;

if ( $check_type eq "space" ) {
  my ( $mount, $warn, $critical ) = @options ;
  open ( DF, "df -kP $mount | grep -v Filesystem |" ) ;
  while ( my $dfline = <DF> ) {
    chomp ( $dfline ) ;
    print STDERR "$dfline\n" if ($debug) ;
    if ( $dfline =~ /.*\s+$mount$/ ) {
      my ($device, $kfree, $pctused) = ("", 0, 100) ;
      print "$dfline : matched\n" if ($debug) ;
      $dfline =~ /^(\S+).*\s+(\S+)\s+(\S+)\%\s+$mount$/ ;
      ($device, $kfree, $pctused) = ($1, $2, $3) ;
      if ( ( 100 - $pctused ) <= $critical ) {
        print "critical: $device on $mount - $pctused% used, ${kfree}KB free\n" ;
        exit (2) ;
      } elsif ( ( 100 - $pctused ) <= $warn ) {
        print "warning: $device on $mount - $pctused% used, ${kfree}KB free\n" ;
        exit (1) ;
      } elsif ( ( 100 - $pctused ) > $warn ) {
        print "ok: $device on $mount - $pctused% used, ${kfree}KB free\n" ;
        exit (0) ;
      } else {
        print "critical: unknown condition\n" ;
        exit (2) ;
      }
    }
  }
  print "critical: mount $mount not found\n" ;
  exit (2) ;
} elsif ( $check_type eq "nfs" ) {
  my %wantopt ;
  my ( $remote, $mount, $wantoptions ) = @options ;
  my $wrongopt = 0 ;
  my @missedopt = () ;
  my @wantoptions = split(/,/, $wantoptions) ;
  foreach my $wantopt ( @wantoptions ) {
    $wantopt{$wantopt} = 1 ;
  }
  open ( MOUNT, "mount | grep 'type nfs' |" ) ;
  while ( my $mountline = <MOUNT> ) {
    if ( $mountline =~ /^$remote\s+on\s+$mount\s+.*\((.*)addr/ ) {
      my @realoptions = split(/,/, $1) ;
      if ( $wantopt{rw} == 1 ) {
        if ( -d "$mount/.nagios" ) {
          if ( system("touch $mount/.nagios/nfstest-$hostname &> /dev/null && rm -f $mount/.nagios/nfstest-$hostname &> /dev/null") ) {
            print "critical: $remote mounted on $mount rw, .nagios directory found, not writeable\n" ;
            exit (2) ;
          }
        } else {
          print "critical: $remote mounted on $mount rw, but no .nagios directory\n" ;
          exit (2) ;
        }
      }
      foreach my $realopt ( @realoptions ) {
        $wantopt{$realopt} = 0 ;
      }
      foreach my $finalopt ( keys %wantopt ) {
        if ( $wantopt{$finalopt} == 1 ) {
          push ( @missedopt, $finalopt ) ;
          $wrongopt = 1 ;
        }
      }
      if ( $wrongopt ) {
        my $missedopt = join(',', @missedopt) ;
        print "critical: $remote mounted on $mount without options $missedopt\n" ;
        exit (2) ;
      } else {
        my $realopt = join(',', @realoptions) ;
        print "ok: $remote mounted on $mount with options $realopt\n" ;
        exit (0) ;
      }
    }
  }
  print "critical: $remote not mounted on $mount\n" ;
  exit (2) ;
}

