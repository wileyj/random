#!/usr/bin/perl

use strict;
use POSIX;
use Getopt::Long;
my $total=0;
my $time=time;
my $record;
my $debug;
my $critical;
my $warning;
my $message="";
my $status;
my $help;
GetOptions ('debug' => \$debug, 'help' => \$help, 'critical=s' => \$critical, 'warning=s' => \$warning);
if ($help){
  print "usage: nfs-ops.pl <options>\n";
  print "options:\n";
  print "\t-d -> run the script with debug output\n";
  print "\t-h -> this message\n";
  exit 0;
}
if (!$critical && !$warning){
  $critical=1000;
  $warning=700;
  print "Using Defaults:\n\tCritical: 1000\n\tWarning:700\n" if ($debug);
}
elsif ($critical && !$warning){
  print "Critical Defined, Warning is not\n" if ($debug);
  print "UNKNOWN: warning threshold not defined";
  exit(3); 
}
elsif(!$critical && $warning){
  print "Warning Defined, Critical is not\n" if ($debug);
  print "UNKNOWN: critical threshold not defined";
  exit(3);
}else{
  print "Using Thresholds:\n\tCritical: $critical\n\tWarning: $warning\n" if ($debug);
}
my $cmd_line = "/usr/sbin/nfsstat -c";
my $i = 0;
my @output = `$cmd_line`;
my $datafile="/tmp/nfs.ops";
if (-f $datafile){
  print "FOUND datafile\n" if ($debug);
  open(FILE, "$datafile");
  chomp($record = <FILE>);
  close FILE;
print "Retrieved old record: $record\n" if ($debug);
}else{
  print "NO datafile found\n" if ($debug);
  # no datafile found
  $status=1;
  $message="WARNING: Created Data file /tmp/nfs.ops. No Data Yet";
}
&getOps;
if ($record ne ""){
  &compareOps;
}
print $message;
exit($status);
sub compareOps(){
  print "Comparing Data...\n" if ($debug);
  my @split=split(":", $record);
  my $previousValue=$split[0];
  my $previousTime=$split[1];
  my $currentValue=$total;
  my $currentTime=$time;
  my $valueDiff=$currentValue-$previousValue;
  my $timeDiff=$currentTime-$previousTime;
  if ($timeDiff >0){
    print "Timediff > 0 :: timediff=$timeDiff\n" if ($debug);
    my $values_per_sec=ceil($valueDiff/$timeDiff);
    if ($values_per_sec >= $critical){
      print "CRITICAL: $values_per_sec nfs ops/s\n" if ($debug);
      $message="CRITICAL: $values_per_sec nfs ops/s";
      $status=2;
    }elsif($values_per_sec >= $warning && $values_per_sec <= $critical-1){
      print "WARNING: $values_per_sec nfs ops/s\n" if ($debug);
      $message="WARNING: $values_per_sec nfs ops/s";
      $status=1;
    }elsif($values_per_sec <= $warning-1){
      print "OK: $values_per_sec nfs ops/s\n" if ($debug);
      $message="OK: $values_per_sec nfs ops/s";
      $status=0;
    }
  }else{
    print "UNKNOWN: Time hasn't changed. time diff=$timeDiff\n" if ($debug);
    $message="UNKNOWN: Time hasn't changed. time diff=$timeDiff";
    $status=3;
  }
  
} 
sub getOps(){
  print "Storing NFS ops data...\n" if ($debug);
  print "datafile: $datafile\n" if ($debug);
  open (FILE, ">$datafile");
  while ($i <= $#output) {
    if (($output[$i] =~ (/^Connection/)) || ($output[$i] =~ (/^Client/)) || ($output[$i] =~ (/^Version/)) || ($output[$i] =~ (/^$/))) {
      $i++;
      next;
    }
    my @string = split /\s+/, $output[$i];
    my @int = split /\s+/, $output[++$i];
    my $xy = 0;
    my $yz = 0;
    while ($xy <= $#string) {
      if ($int[$yz] =~ /%/) {
        $yz++;
      }
      #print "string $string[$xy]\n";
      #print "int $int[$yz]\n";
      $total=$total+$int[$yz];
      $xy++;
      $yz++;
    }
    $i++;
  }
  print "total: $total\n" if ($debug);
  print "time: $time\n" if ($debug);
  print FILE "$total:$time";
}
