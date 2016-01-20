#!/usr/bin/perl
# nrpe.cfg line:
# command[check_drbd]=/opt/nagios/libexec/check_drbd.pl 

$proc_file="/proc/drbd";
$drbd_file="/etc/drbd.conf";
$hostname=`hostname`;
chomp $hostname;
my @nagios_state;
my @nagios_message;
  if ($ARGV[0] eq "-h"){
 print "
usage: check_drbd.pl <option>
  -h = this usage message
  -d = debug
";
exit 0;
}
if ($ARGV[0] eq "-d"){
  $debug=1;
}

open (FILE, "$proc_file");
@lines=<FILE>;
close FILE;

my %state = (
  'Primary' => 		{ 'state' => '0', 'type' => 'ro' },
  'Secondary' => 	{ 'state' => '0', 'type' => 'ro' },
  'Unknown' => 		{ 'state' => '2', 'type' => 'ro' },
  'Connected' => 	{ 'state' => '0', 'type' => 'cs' },
  'StandAlone' => 	{ 'state' => '1', 'type' => 'cs' },
  'Unconfigured' => 	{ 'state' => '2', 'type' => 'cs' },
  'Unconnected' => 	{ 'state' => '2', 'type' => 'cs' },
  'Timeout' => 		{ 'state' => '2', 'type' => 'cs' },
  'BrokenPipe' => 	{ 'state' => '2', 'type' => 'cs' },
  'WFConnection' => 	{ 'state' => '2', 'type' => 'cs' },
  'WFReportParams' =>	{ 'state' => '2', 'type' => 'cs' },
  'SyncingAll' => 	{ 'state' => '1', 'type' => 'cs' },
  'SyncingQuick' => 	{ 'state' => '1', 'type' => 'cs' },
  'SyncPaused' => 	{ 'state' => '2', 'type' => 'cs' },
  'SyncSource' => 	{ 'state' => '1', 'type' => 'cs' },
  'SyncTarget' => 	{ 'state' => '1', 'type' => 'cs' },
  'NetworkFailure' => 	{ 'state' => '2', 'type' => 'cs' },
  'SkippedSyncS' => 	{ 'state' => '2', 'type' => 'cs' },
  'SkippedSyncT' => 	{ 'state' => '2', 'type' => 'cs' },
  'WFBitMapS' => 	{ 'state' => '2', 'type' => 'cs' },
  'WFBitMapT' => 	{ 'state' => '2', 'type' => 'cs' },
  'PausedSyncS' => 	{ 'state' => '2', 'type' => 'cs' },
  'PausedSyncT' => 	{ 'state' => '2', 'type' => 'cs' },
  'VerifyT' =>          { 'state' => '1', 'type' => 'cs' },
  'VerifyS' =>          { 'state' => '1', 'type' => 'cs' },
  'Inconsistent' => 	{ 'state' => '2', 'type' => 'ds' },
  'UpToDate' => 	{ 'state' => '0', 'type' => 'ds' },
  'Consistent' => 	{ 'state' => '0', 'type' => 'ds' },
  'Negotiating' => 	{ 'state' => '1', 'type' => 'ds' },
  'Attaching' => 	{ 'state' => '1', 'type' => 'ds' },
  'Diskless' => 	{ 'state' => '2', 'type' => 'ds' },
  'Failed' => 		{ 'state' => '2', 'type' => 'ds' },
  'Outdated' => 	{ 'state' => '2', 'type' => 'ds' },
  'DUnknown' => 	{ 'state' => '2', 'type' => 'ds' }
);
%return_state = (
  '0' => "DRDB OK:",
  '1' => "DRBD WARNING:",
  '2' => "DRBD CRITICAL:",
  '3' => "DRBD UNKNOWN:"
);

open(DRBD_CONF, "$drbd_file");
@drbd_lines=<DRBD_CONF>;
close DRBD_CONF;
$drbd_conf_len=scalar(@drbd_lines);
for ($j=0;$j<$drbd_conf_len;$j++){
  if ($drbd_lines[$j]=~/$hostname/){
    $drbd_device=$drbd_lines[$j+1];
    $drbd_device=~s/device//g;
    $drbd_device=~s/\/dev\///g;
    $drbd_device=~s/\ //g;
    $drbd_device=~s/\;//g;
    $drbd_devnum=substr($drbd_device,4,1);
    print "Found Device $drbd_devnum\n"if($debug);
    &parse_proc;
  }
}

print "Finding Correct Nagios State\n" if ($debug);
$nagios_len=scalar(@nagios_state);
$message_len=scalar(@nagios_message);
my $ret_val;
for ($i=0;$i<$nagios_len;$i++){
  if ($i==0){
    $ret_val=$nagios_state[$i];
  }else{
    if ($nagios_state[$i] > $ret_val){
      $ret_val=$nagios_state[$i];
      print "Found higher return val. setting return to $ret_val\n"if ($debug);
    }
  }
}
print "Return Value: $ret_val\n"if($debug);

for($x=0;$x<$message_len;$x++){
  if ($message_len > 1 && $x<$message_len-1){
    print "$return_state{$ret_val}"."$nagios_message[$x]<BR>";
  }else{
    print "$return_state{$ret_val}"."$nagios_message[$x]";
  }
}
exit ($ret_val);

sub parse_proc(){
  print "Parsing details for Device: $drbd_devnum\n" if ($debug);
  print "Reading $proc_file\n"if ($debug);
  $procfile_len=scalar(@lines);
  for ($i=0; $i<$procfile_len;$i++){
    if ($lines[$i]=~/$drbd_devnum:/){
      print "Found device lines for device $drbd_devnum\n"if ($debug);
      $line1=$lines[$i];
      $line2=$lines[$i+1];
      chomp $line1;
      chomp $line2;
    }
  }
  @split_line1=split(" ", $line1);
  @split_line2=split(" ", $line2);
  $connect_state=$split_line1[1];		$connect_state=~s/cs://g;
  $role=$split_line1[2];			
  if ($role=~/ro:/){ $role=~s/ro://g;}
  else{ $role=~s/st://g;}
  $disk_state="$split_line1[3]";		$disk_state=~s/ds://g;
  $network_send=$split_line2[0];		$network_send=~s/ns://g;
  $network_receive=$split_line2[1];		$network_receive=~s/nr://g;
  $disk_write=$split_line2[2];			$disk_write=~s/dw://g;
  $disk_read=$split_line2[3];			$disk_read=~s/dr://g;
  $activity_log=$split_line2[4];		$activity_log=~s/al://g;
  $bit_map=$split_line2[5];			$bit_map=~s/bm://g;
  $local_count=$split_line2[6];			$local_count=~s/lo://g;
  $pending=$split_line2[7];			$pending=~s/pe://g;
  $unacknowledged=$split_line2[8];		$unacknowledged=~s/ua://g;
  $application_pending=$split_line2[9];		$application_pending=~s/ap://g;
  $epochs=$split_line2[10];			$epochs=~s/ep://g;
  $write_order=$split_line2[11];		$write_order=~s/wo://g;
  $out_of_sync=$split_line2[12];		$out_of_sync=~s/oos://g;
  @split_ro=split("\/", $role);
  $role=$split_ro[0];
  @split_ds=split("\/", $disk_state);
  $disk_state=$split_ds[0];

  print "Getting state values from hashtable\n"if ($debug);
  $cs_val=$state{$connect_state}->{'state'};
  $ro_val=$state{$role}->{'state'};
  $ds_val=$state{$disk_state}->{'state'}; 
  print "Evaluating Connect state/Role/Disk State\n" if ($debug);
    print "\n" if ($debug);
    print "connect_state return val: $cs_val\n" if ($debug);
    print "role return val: $ro_val\n" if ($debug);
    print "disk_state return val: $ds_val\n" if ($debug);
    print "\n"if ($debug);
  if ($cs_val==0 && $ro_val==0 && $ds_val==0){
    $state=0;
    $message="Device: $drbd_devnum $role $connect_state $disk_state"; 
    print "OK: Device $drbd_devnum $role $connect_state $disk_state\n"if ($debug);
    print "Setting state to $state\n"if($debug);
  }elsif($cs_val==1 || $ro_val==1 || $ds_val==1){
    $state=1;
    $message="Device $drbd_devnum $role $connect_state $disk_state";
    print "WARNING: Device $drbd_devnum $role $connect_state $disk_state\n"if ($debug);
    print "Setting state to $state\n"if($debug);
  }elsif($cs_val==2 || $ro_val==2 || $ds_val==2){
    $state=2;
    $message="Device $drbd_devnum $role $connect_state $disk_state";                                        
    print "CRITICAL: Device $drbd_devnum $role $connect_state $disk_state\n"if ($debug);     
    print "Setting state to $state\n"if($debug);
  }else{
    $state=3;
    $message="Device $drbd_devnum $role $connect_state $disk_state";
    print "CRITICAL: Device $drbd_devnum $role $connect_state $disk_state\n"if ($debug);
    print "Setting state to $state\n"if($debug);
  }
  push(@nagios_state, $state);
  push (@nagios_message, $message);
  print "Finished Reading Device $drbd_devnum\n" if ($debug);
}
