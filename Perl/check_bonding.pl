#!/usr/bin/perl

use Getopt::Long;
my $iface = '';
my $mode = '';
GetOptions ('iface=s' => \$iface, 'type=s' => \$mode);
if ($iface eq "" || $mode eq ""){
  print "critical:Bad CMD Options:NA:NA:NA:NA:NA";
  exit 2;
}
if (!-f "/proc/net/bonding/$iface"){
  print "critical:$iface: $mode (BOND NOT FOUND):eth0:NA:eth1:NA";
  exit 2;
}
open (FILE, "/proc/net/bonding/$iface");
@lines=<FILE>;
close FILE;
my $count = 0;
my $slave_count = 0;
$ignore_result = 0;
my $return = "";
my $show_correct = "";
foreach $line(@lines){
  if ($line =~/Bonding Mode/){
    $mode_line = $line;
    @getmode=split(" ", $mode_line);
    $mode1 = $getmode[3];
    $mode1=~s/\(//g;  
    $mode1=~s/\)//g;  
    if ($mode ne "$mode1"){
      $alarm = "critical:";
      $exit_code="2";
      $ignore_result = 1;
      $show_correct=" (should be $mode )"; 
    }
    $return="$return"."$iface".":"."$mode1"."$show_correct";
  }
  if ($line =~/Primary Slave/){
    @getslave=split(" ", $line);
    $primary_slave = $getslave[2];
  }
  if ($line =~/Currently Active/ && $mode eq "active-backup"){
    @cactive=split(" ", $line);
    $active_iface = $cactive[3];
    if ($primary_slave ne "None"){
      if ($active_iface ne "$primary_slave"){
        $alarm = "warning";
        $exit_code = "1";
        $ignore_result = 1;
      }
    }
  }
  if ($line=~/Slave Interface/){
    $slave_count++;
    @this=split(" ", $line);
    $nic=$this[2];
    $nic_up = $lines[$count+1];
    @that=split(" ", $nic_up);
    $status=$that[2];
    if ($status ne "up"){
      $alarm = "critical";
      $ignore_result = 1;
    }
    $return = "$return".":"."$nic".":"."$status";
  }
  $count ++;
}
if ($ignore_result == 0){
  $alarm="ok";
  $exit_code="0";
}
if ($slave_count < 2){
  $alarm="critical";
  $exit_code="2";
}
print "$alarm".":"."$return\n";
exit $exit_code;

