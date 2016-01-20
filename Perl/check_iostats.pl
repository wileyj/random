#!/usr/bin/perl

#major scsi block = 8 : minor is 0,16,32,48,64 etc
# ex: /dev/sda=8,0 : /dev/sdb=8,16 : /dev/sdc=8,32
#major ide block = 3 - same minor numbers
# xen disks = 202 - same minor numbers
$debug=1;
$ignore=0;
$nodisk_found=1;
$disk_count=0;
$num_skipped=0;
$tempfile="/tmp/statsfile";
if (!-f "$tempfile"){
  print "NOT FOUND: $tempfile\n" if ($debug == 1);
  print "Creating $tempfile before continuing\n\n" if ($debug == 1);
  open (STATSFILE, ">$tempfile");
  close STATSFILE;
  $ignore=1;
}
if (-f "$tempfile"){
  $filesize= (stat($tempfile))[7];
  if ($filesize <= 1){
    $ignore=1;
  }
}
$date=time;
$statsfile="/proc/diskstats";
if (!-f $statsfile){
  $state=2;
  $message="CRIT: missing /proc/diskstats";
print "return 31\n";
  &return;
}
$multiple=0;
open (STATS, "$statsfile");
@stats=<STATS>;
close STATS;
open(READ, "$tempfile");
@readlines=<READ>;
close READ;
$previoustime=0;
$currenttime=$date;
$readline_len=scalar(@readlines);
my %old=();
my %new=();
if ($readline_len > 0){
  foreach $read(@readlines){
    chomp $read;
    @get=split(" ", $read);
    print "Reading Old Values of /dev/$get[1]\n" if ($debug == 1);      
    $old_device=$get[1];
    $old_read=$get[2];
    $old_write=$get[3];
    $previoustime=$get[0];
    $old{$old_device}->{'device'}=$old_device;
    $old{$old_device}->{'read'}=$old_read;
    $old{$old_device}->{'write'}=$old_write;
    $old{$old_deivce}->{'time'}=$previoustime;
  }
  print "Getting Time Difference...\n" if ($debug == 1);
  $time=$currenttime-$previoustime;
  print "Elapsed time is: $time s\n" if ($debug == 1);
}else{
  if ($ignore == 1){
    $state=2;
    $message="Created $tempfile";
  }else{
    $state=1;
    $message="No data in $tempfile";
  }
  print "return 71\n";
  &return;
}
open (WRITE, ">$tempfile");
$stats_len=scalar(@stats);
print "stats_len: $stats_len\n";
foreach $line(@stats){
  $skip = 0;
  chomp $line;
  @splitline=split(" ", $line);
  if ($splitline[0] == 202 || $splitline[0] == 8 || $splitline[0] == 3){
    $nodisk_found=0;
    @splitthis=split(" ", $line);
    if ($splitthis[2]=~/[0-9]/){}
    else{
      $disk_count++;
      $device=$splitthis[2];
      $read=$splitthis[5];
      $write=$splitthis[7];
      if ($device =~/[0-9]/)   { $skip = 1;print "skipping because of device: $device\n";}
      if ($read  =~/[a-zA-Z]/) { $skip = 1; print "skipping because of read: $read\n";}
      if ($write =~/[a-zA-Z]/) { $skip = 1; print "skipping because of write: $write\n";}

      if ($device=~/[a-zA-Z]/ && $skip == 0){
        $old_read=$old{$device}->{'read'} if ($ignore != 1);
        $old_write=$old{$device}->{'write'} if ($ignore != 1);
        print WRITE "$date $device $read $write\n";
        if ($ignore != 1){
          $readspeed=(($read-$old_read)/$time)*512;
          $writespeed=(($write-$old_write)/$time)*512;
#print "origread: $readspeed\n";
          $readspeed=0.1*int(0.5+$readspeed/0.1);
#print "roundread: $readspeed\n";
#print "origwrite: $writespeed\n";
          $writespeed=0.1*int(0.5+$writespeed/0.1);
#print "roundwrite: $writespeed\n";
        }
        if ($readspeed > 1024){
          $readspeed=$readspeed/1024;
          $speed="kb";
        }else{
          $speed="b";
        }
        if ($writespeed > 1024){
          $writespeed=$writespeed/1024;
          $speed="kb";
        }else{
          $speed="b";
        }
        if ($ignore != 1){
          print "------- Details for /dev/$device -------\n" if ($debug == 1);
          print "Read Speed: $readspeed $speed/s\n" if ($debug ==1);
          print "Write Speed: $writespeed $speed/s\n" if ($debug ==1);
          print "\n" if ($debug == 1);
          $state=0;
          $message="$message"."/dev/$device: read=$readspeed $speed/s | write=$writespeed $speed/s\n";
        }
      }else{
        $num_skipped++;
        $skipped_devices="$skipped_devices"." /dev/$device";
      }
    }
  } 
}
if ($nodisk_found == 1){
  $state=2;
  $message="CRIT: no disks found";
  print "return 130\n";
  &return;
}
if ($num_skipped > 0){
  $state=2;
  $message="CRIT: problem reading info or disks: $skipped_devices";
  print "return 136\n";
  &return;
}
print "return 139\n";
&return;
close WRITE;

sub return(){
  print "in return\n" if ($debug == 1);
  print "state: $state\n" if ($debug == 1);
  print "message: $message\n" if ($debug == 1);
}
exit 0;