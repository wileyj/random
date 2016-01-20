#!/usr/bin/perl
$hostname=`hostname`;
open (LOG, ">>/output/logfile.txt");
print LOG "**** CHECKING $hostname"; 
opendir(DIR, "/etc/sysconfig/network-scripts/");
@dir=readdir DIR;
close DIR;

$iface=`netstat -rn | grep "^0.0.0.0" |grep UG | awk '{print \$8}'`;
chomp $iface;
$ipaddr=`cat /etc/sysconfig/network-scripts/ifcfg-$iface | grep IPADDR | cut -d"=" -f2`;
print LOG "\tprimary interface: $iface\n";
print LOG "\tip: $ipaddr\n";
if ($ipaddr=~/172.16/ || $ipaddr=~/172.17/){
  print LOG "need correct route \n";
}
my $file="";
foreach $item(@dir){
chomp $item;
  if ($item =~/route-$iface/){
    $file="/etc/sysconfig/network-scripts/$item";
    $command=`grep "10.0.0.0/8 via 172.16.0.1" $file`;
  }
}
if ($file eq ""){
  print LOG "\t NO ROUTE FILE for $iface";
}elsif ($file ne "" && $command eq ""){
  print LOG "\t ROUTE 10.0.0.0/8 via 172.16.0.1 MISSING in $file";
}else{
  print LOG "GOOD $file : $command";
}

print LOG "\n\n";

exit 0;

