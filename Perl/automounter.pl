#!/usr/bin/perl
use Getopt::Long;
use strict;

my $run_user=$ENV{USER};
if ($run_user ne "root"){
  print "needs to run as root or by sudo. exiting\n";
  exit 1;
}
my %fstab_mounts;
my %mounted;
my %df_data;
my $return=0;
my $regex;
my $debug;
my $help;
my $mount;
my $mount_return;
my $remount;
my $remount_return;
my $force_unmount;
my $force_unmount_return;
my $mount2;
my $mount2_return;
my $mountdir;
my $df;

GetOptions (
  'regex=s'      => \$regex,
  'debug'        => \$debug, 
  'help'         => \$help
);
if ($regex){
  print "Searching for Matching Mounts for: $regex\n" if ($debug);
  $regex=~s/\*//g;
}
open(FSTAB, "/etc/fstab");
my @fstab=<FSTAB>;
close FSTAB;

foreach my $line(@fstab){
  chomp $line;
  my @split=split(" ", $line);
  if ($split[2] eq "nfs" || $split[2] eq "ext3"){
    my $comment=substr($split[0],0,1);
    if ($comment!~/#/){
      #push into hash
      #$fstab_mounts{$split[0]}=$split[1]; 
      if ($regex){
        if ($split[0]=~/boot/ || $split[0]=~/devpts/ || $split[0]=~/tmpfs/ || $split[0]=~/sysfs/ || $split[0]=~/proc/ || $split[1]=~/swap/){}
        elsif ($split[2]=~/ext3/ && $split[1]=~m/$regex/i){
          my @this=split("/", $split[0]);
          $mount="/dev/mapper/"."$this[2]"."-"."$this[3]";
          $mountdir=$split[1];
          $fstab_mounts{$mount}=$mountdir;                                                                                                                                           
          print "Adding local Mount to Hash: $mount $fstab_mounts{$mount}\n" if ($debug);                                                                                            
        }elsif ($split[2]=~/nfs/ && $split[1]=~m/$regex/i){
          $mount=$split[0];
          $mountdir=$split[1];
          $fstab_mounts{$mount}=$mountdir;
          print "Adding Regex Mount to Hash: $mount $fstab_mounts{$mount}\n" if ($debug);
        }
      }else{
        if ($split[0]=~/boot/ || $split[0]=~/devpts/ || $split[0]=~/tmpfs/ || $split[0]=~/sysfs/ || $split[0]=~/proc/ || $split[1]=~/swap/){}
        elsif ($split[2]=~/ext3/){
          my @this=split("/", $split[0]);
          $mount="/dev/mapper/"."$this[2]"."-"."$this[3]";
          $mountdir=$split[1];
          $fstab_mounts{$mount}=$mountdir; 
          print "Adding local Mount to Hash: $mount $fstab_mounts{$mount}\n" if ($debug);
        }
        elsif ($split[2]=~/nfs/){
          $mount=$split[0];
          $mountdir=$split[1];
          $fstab_mounts{$mount}=$mountdir; 
          print "Adding nfs Mount to Hash: $mount $fstab_mounts{$mount}\n" if ($debug);
        }
      }
    }
  }
}
print "\n" if ($debug);
eval {
  local $SIG{ALRM} = sub {die "alarm\n"};
  alarm 10;
  $df = `df -P | grep -v Filesystem`;
  alarm 0;
};
if ($@) {
  die unless $@ eq "alarm\n";
  print "\"df -P\" Timed Out\n";
}
else {
  print "df command returned correctly\n" if ($debug);
}
print "Processing Continues...\n\n" if ($debug);

my @split_line=split("\n", $df);
foreach my $line(@split_line){
  my @line_data=split(" ", $line);
  $df_data{$line_data[0]}={
    'filesystem'=>$line_data[0],
    'blocks'    =>$line_data[1],
    'used'      =>$line_data[2],
    'available' =>$line_data[3],
    'capacity'  =>$line_data[4],
    'mounted'   =>$line_data[5]
  }; 
}

foreach my $item(sort keys %fstab_mounts){
  my $filesystem=$df_data{$item}{'filesystem'};
  my $blocks=$df_data{$item}{'blocks'};
  my $used=$df_data{$item}{'used'};
  my $available=$df_data{$item}{'available'};
  my $capacity=$df_data{$item}{'capacity'};
  my $mounted=$df_data{$item}{'mounted'};
  my @get=split(" ", $item);
  if ($item ne $filesystem){
    print "Not Mounted: $fstab_mounts{$item}\n" if ($debug);
    print "Mounting: $item\n" if ($debug);
    $mount=`/bin/mount $fstab_mounts{$item}`;
    $mount_return=$?;
    if ($mount_return == 0){
      print "\t$fstab_mounts{$item} has been Mounted\n" if ($debug);
    }
  }elsif ($blocks eq "-" && $used eq "-" && $available eq "-" && $capacity eq "-" ){
    print "Stale Mount: $fstab_mounts{$item}\n" if ($debug);
    print "\t Need to Remount $item\n" if ($debug);
    $remount=`/bin/mount -o remount $fstab_mounts{$item}`;
    $remount_return=$?;
    if ($remount_return == 0){
      print "\t$fstab_mounts{$item} has been Mounted\n"  if ($debug);
    }elsif($remount_return == 8192){
      print "\tFailed Remount. Doing Force unmount/mount...\n"  if ($debug);
      $force_unmount=`/bin/umount -lf $fstab_mounts{$item}`;
      $force_unmount_return=$?;
      if($force_unmount_return == 0){
        $mount2=`/bin/mount $fstab_mounts{$item}`;
        $mount2_return=$?;
        if ($mount2_return == 0){
          print "\t$fstab_mounts{$item} has been Remounted\n" if ($debug);
        }else{
          print "\t$fstab_mounts{$item} Failed\n" if ($debug);
          $return=2;
        }
      }else{
        print "\t$fstab_mounts{$item} Force Unmount Failed\n" if ($debug);
        $return=2;
      }
    }
  }else{
    print "Mount OK $filesystem\n" if ($debug);
  }
}
exit($return);
