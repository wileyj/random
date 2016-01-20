#!/usr/bin/perl
use Getopt::Long;
GetOptions ('force' => \$force, 'debug' => \$debug);
$file="lv.txt";
$command="cat $file | grep tsflatfs-";
my %h_hash;
my %d_hash;
my $hostname=`hostname`;

if ($debug){
  print "DEBUG ON\n";
  $debug=1;
}else{
  $debug=0;
}
if ($force){
  print "Autoreply (force) \"yes\" response ON\n" if ($debug);
  $force="-f"
}else{
  print "Autoreply OFF\n" if ($debug);
  $force="";
}

print "Running command $command\n" if ($debug);
$this=`$command`;
@split_line=split("\n", $this);
foreach $item(@split_line){
  @get=split(" ", $item);
  $lv=$get[0];
  $vg=$get[1];
  $theHour=substr($lv, 26,2); chomp $theHour;
  if ($theHour){
    print "Found Hourly LV: $lv\n" if ($debug);
    push(@hourly, $lv);
    $h_hash{$lv}={
      'lv' => $lv,
      'vg' => $vg
    };
  }else{
    print "Found Daily LV: $lv\n" if ($debug);
    push(@daily, $lv);
    $d_hash{$lv}={
      'lv' => $lv,
      'vg' => $vg
    };
  }
}
&daily;
&hourly;
print "Completed process\n" if ($debug);
exit 0;

sub daily(){
  print "Processing Daily LV's\n" if ($debug);
  $len=keys(%d_hash);
  print "Total Hourly LV's: $len\n" if ($debug);
  $count=0;
  foreach my $item(reverse sort keys %d_hash){
    $theHour=substr($d_hash{$item}{'lv'}, 26, 2); 
    $vg=$d_hash{$item}{'vg'};
    $lv=$d_hash{$item}{'lv'};
    if ($count < 3){
      print "Preserve Daily LV: $lv from $vg\n" if ($debug);
    }else{
      print "Deleting Daily LV: $lv from $vg\n" if ($debug);
      $check_lv=`/usr/sbin/lvs $vg/$lv`;
      if ($? == 0){
        print "run lvremove $force $vg/$lv\n";
        if ($? != 0){
          print "Error code $? removing lv $vg/$lv (return $?): $runCmd \n" if ($debug);
          $message="Error code $? removing lv $vg/$lv: $runCmd on $hostname\n";
        }
      }else{
        print "Error finding $vg/$lv (return $?). Aborting script\n";
        $message= "Error finding $vg/$lv (return $?). Script Aborted on $hostname\n";
        &email;
      }
    }
    $count++;
  }
  print "End of Daily LV's\n" if ($debug);
}
sub hourly(){
  print "Processing Hourly LV's\n" if ($debug);
  $len=keys(%h_hash);
  print "Total Hourly LV's: $len\n" if ($debug);
  $count=0;
  foreach my $item(reverse sort keys %h_hash){
    $theHour=substr($h_hash{$item}{'lv'}, 26, 2);
    $vg=$h_hash{$item}{'vg'};
    $lv=$h_hash{$item}{'lv'};
    chomp $theHour;
    $number = $theHour/4;
    if( $number=~/\D/ && $count > 3 ){
      print "Deleting LV: $lv from $vg\n" if ($debug);
      print "\tHour Field: $theHour\n" if ($debug);
      print "\t$theHour/4 = $number\n" if ($debug);
      $check_lv=`/usr/sbin/lvs $vg/$lv`;
      if ($? == 0){
        print "run lvremove $force $vg/$lv\n";
        if ($? != 0){
          print "Error code $? removing lv $vg/$lv (return $?): $runCmd \n" if ($debug);
          $message="Error code $? removing lv $vg/$lv (return $?): $runCmd on $hostname\n";
        }
        &email;
      }else{
        print "Error finding $vg/$lv (return $?). Aborting script\n" if ($debug);
        $message="Error finding $vg/$lv (return $?). Script Aborted on $hostname\n";
        &email;
      }
    }elsif ($number=~/^\d+\z/ || $count <= 3){
      if ($count <=3){
        print "LV $count: Keeping $lv from $vg\n" if ($debug);
      }else{
        print "Keeping $lv from $vg\n" if ($debug);
        print "\t$theHour/4 = $number\n" if ($debug);
      }
    }else{
      print "Skipping: $lv from $vg\n" if ($debug);
      print "\t$theHour/4 = $number != regex\n" if ($debug);
      print "Skipping LV: $lv from $vg - failed to match regex\n";
    }
    $count++;
  }
  print "End of Hourly LV's\n" if ($debug);
}
sub email(){
  print "Sending Email\n" if ($debug);
  print "message: $message\n";
  exit 1;
}
