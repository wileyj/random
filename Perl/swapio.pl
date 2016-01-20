#!/usr/bin/perl

use strict;
use POSIX;
use Getopt::Long;

my $record;
my $debug;
my $read_critical;
my $read_warning;
my $write_critical;
my $write_warning;
my $message="";
my $status;
my $help;
my $datafile="/var/tmp/swap.ops";
my $diskstats="/proc/diskstats";
my $dev;
my $o_read = 0;
my $o_write = 0;
my $o_date;
my $n_read = 0;
my $n_write = 0;
my $n_date=time;
my $readspeed;
my $writespeed;
my $found = 0;

GetOptions (
  'rc=s'  => \$read_critical,
  'rw=s'  => \$read_warning,
  'wc=s'  => \$write_critical,
  'ww=s'  => \$write_warning,
  'debug' => \$debug,
  'help'  => \$help
);
if ($help){
  logger("Usage: $0",0);
  logger("   -rc = threshold for read critical",0);
  logger("   -rw = threshold for read warning",0);
  logger("   -wc = threshold for write critical",0);
  logger("   -ww = threshold for write warning",0);
  logger("   -d = run in debug mode",0);
  logger("   -h = This help message",0);
  logger("", 0);
  logger("ex: $0 -ww 10 -wc 15 -rw 10 -rc 15", 0);
  logger("", 0);
  exit 0;
}

logger("\n----------------------------------",1);
if (-f $datafile){
  logger("FOUND datafile: $datafile", 1);
  open(FILE, "$datafile");
  chomp($record = <FILE>);
  close FILE;
  logger("Retrieved old record: $record", 1);
  my @split_old = split(" ", $record);
  $o_date = $split_old[0];
  $o_read = $split_old[1];
  $o_write = $split_old[2];
  $found = 1;
}
logger("Retrieving swap devices", 1);
open(SWAP, "/sbin/swapon -s | grep 1|");
while(<SWAP>){
  my ($filename, $type, $size, $used, $priority) = split;
  chomp $filename;
  chomp $type;
  chomp $size;
  chomp $used;
  chomp $priority;
  logger("\n----------------------------------",1);
  if ($filename=~/mapper/){
    logger("Found a mapped swap device: $filename", 1);
    my $dev_name = `ls -al $filename`;
    my ($perm, $size, $uid, $gid, $major, $minor, $month, $day, $year, $device) = split(" ", $dev_name);
    $dev = "dm-".$minor;
  }else{
    logger("Found swap device: $filename", 1);
    $filename=~s/\/dev\///g;
    $dev = $filename;
  }
  logger("Swap Device Name: $dev",1);
  &getOps($dev);
}
if ($status != 1){
  logger("\n----------------------------------",1);
  logger("Comparing old vs new values",1);
  my $time = $n_date  - $o_date;
  logger("\tElapsed Time:  $time",1);
  $readspeed=(($n_read-$o_read)/$time)*512;
  $writespeed=(($n_write-$o_write)/$time)*512;
  logger("\tRaw readspeed: $readspeed", 1);
  logger("\tRaw writespeed: $writespeed", 1);
  $readspeed=0.1*int(0.5+$readspeed/0.1);
  $writespeed=0.1*int(0.5+$writespeed/0.1);
  logger("\tRounded readspeed: $readspeed", 1);
  logger("\tRounded writespeed: $writespeed", 1);
  $readspeed=$readspeed/1024;
  $readspeed=ceil($readspeed);
  $writespeed=$writespeed/1024;
  $writespeed=ceil($writespeed);
  logger("\n----------------------------------",1);
  logger("Read Speed: $readspeed kb/s",1);
  logger("Write Speed: $writespeed kb/s",1);
}
logger("Saving: $n_date $n_read $n_write", 1);
open(FILE, ">$datafile");
print FILE "$n_date $n_read $n_write";
close FILE;
if ($found == 0){
  $status=1;
  $message="WARNING: Created Data file $datafile. No data until the next scheduled check";
  &return($message, $status);
}else{
  if ($readspeed < $read_critical && $writespeed < $write_critical){
    if ($readspeed < $read_warning && $writespeed < $write_warning){
      #OK
      $message = "OK - Read I/O:$readspeed kb/s, Write I/O:$writespeed kb/s";
      $status = 0;
      &return($message, $status);
    }elsif ($readspeed < $read_warning && $writespeed => $write_critical){
      #write is warning
      $message = "Write WARN - Read I/O:$readspeed kb/s, Write I/O:$writespeed kb/s";
      $status = 1;
      &return($message, $status);
    }elsif($readspeed => $read_warning && $writespeed < $write_warning){
      # read is warning
      $message = "Read WARN - Read I/O:$readspeed kb/s, Write I/O:$writespeed kb/s";
      $status = 1;
      &return($message, $status);
    }elsif($readspeed => $read_warning && $writespeed => $write_warning){
      #read & write are warning
      $message = "WARN - Read I/O:$readspeed kb/s, Write I/O:$writespeed kb/s";
      $status = 1;
      &return($message, $status);
    }else{
      #unkown
      $message = "UNKNOWN - Read I/O:$readspeed kb/s, Write I/O:$writespeed kb/s";
      &return($message, $status);
    }
  }elsif ($readspeed < $read_critical && $writespeed => $write_critical){
    # write is critical
    $message = "Write CRIT - Read I/O:$readspeed kb/s, Write I/O:$writespeed kb/s";
    $status = 2;
    &return($message, $status);
  }elsif ($readspeed => $read_critical && $writespeed < $write_critical){
    # read is critical
    $message = "Read CRIT - Read I/O:$readspeed kb/s, Write I/O:$writespeed kb/s";
    $status = 2;
    &return($message, $status);
  }elsif($readspeed => $read_critical && $writespeed => $write_critical){
    # read and write are critical
    $message = "CRIT - Read I/O:$readspeed kb/s, Write I/O:$writespeed kb/s";
    $status = 2;
    &return($message, $status);
  }else{
    # unkown
    $message = "UNKOWN - Read I/O:$readspeed kb/s, Write I/O:$writespeed kb/s";
    $status = 3;
    &return($message, $status);
  }
}
# shouldn't be reached
exit 3;

sub return(){
  $message = $_[0];
  $status  = $_[1];
  print $message;
  logger("\n", 1);
  exit($status);
}

sub getOps(){
  my $r_dev = $_[0];
  logger("-- getOps --",1);
  logger("\tReceived Option: $r_dev",1);
  logger("\tRetrieving Swap data from $diskstats", 1);
  my $grep_cmd = `grep $r_dev $diskstats`;
  chomp $grep_cmd;
  my @split = split(" ", $grep_cmd);
  my $len = scalar(@split);
  logger("\tFound $len items", 1);
  my $read;
  my $write;
  if ($len < 8){ # this is a partition, and not a device
    $read = $split[3];
    $write = $split[5];
  }else{
    $read = $split[3];
    $write = $split[7];
  }

  $n_read = $n_read + $read;
  $n_write = $n_write + $write;
  logger("\tCurrent n_read: $n_read",1);
  logger("\tCurrent n_write: $n_write",1);
  undef @split;
}


sub logger{
  my $data = $_[0];
  my $type = $_[1];
  if ($type == 0){
    print "$data\n";
  }else{
    print "$data\n" if ($debug);
  }
  print LOG "$data\n";
}