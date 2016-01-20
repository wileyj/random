#!/usr/bin/perl
use strict ;
use Proc::ProcessTable;
use Getopt::Long ;
use File::stat;

if (!-f "/opt/tivoli/tsm/client/ba/bin/dsm.sys"){
  print "Unable to find dsm.sys at /opt/tivoli/tsm/client/ba/bin/";
  exit(2);
}
my $getschedlog = `grep "SCHEDLOGName" /opt/tivoli/tsm/client/ba/bin/dsm.sys`;
my $geterrorlog = `grep "ERRORLOGName" /opt/tivoli/tsm/client/ba/bin/dsm.sys`;
my @parsesched = split(" ", $getschedlog);
my @parseerror = split(" ", $geterrorlog);
my $schedlog = $parsesched[1];
my $errorlog = $parseerror[1];
if (!-f $schedlog){
  print "Unable to find Log File: "."$schedlog";
  exit(1);
}

my $logoutput;
my $erroroutput;
my $retryoutput;
my $state;
my $answer;
my $transferred;
my $failed;
my $backedup;
my $getstatus;
my $blank; # temp variable
my $timeoffset;

Getopt::Long::Configure ("no_ignore_case") ;
my ($DEBUG,$logfile,$errorfile,$retryfile,$status,$help,$runDSMC,$count,$remove_file);

sub usage(){
print"
Usage: check_tivoli.pl 
Options:
        --DEBUG     (-d) 
        --logfile   (-l) Location of Tivoli logfile
        --errorfile (-e) Location of Tivoli errorlist file
        --retryfile (-r) Location of Tivoli retrylist file
        --help      (-h) Displays this Message
";
exit;
}
my @T=localtime(time+86400);
my $month=$T[4]+1;
my $year=$T[5]+1900;
my $day=$T[3];
if ($day < 10 ){$day = "0".$day;}
if ($month < 10){$month = "0".$month;}

my $tomorrow="$month"."/"."$day"."/"."$year";
my $tomorrow1="$month"."$day"."$year";
my $today= `date +%m/%d/%Y`;
my $time=`date +%H%M%S`;
chomp $today;
chomp $time;

my $today1 = $today;
chomp $today1;
$today1=~s/\///g;

my $reverse = 0;
my $command = "dsmc";
GetOptions(
  "debug|d"      => \$DEBUG,
  "logfile|l"    => \$logfile,
  "errorfile|e"  => \$errorfile,
  "retryfile|r"  => \$retryfile,
  "help|h"       => \$help

);
if ($help){
  &usage;
}
print "Using Tivoli Scheduler File: $schedlog\n" if ($DEBUG);
print "Using Tivoli Error File: $errorlog\n" if ($DEBUG);

print "Today's date: $today\n" if ($DEBUG);
print "Tomorrow's date: $tomorrow\n" if ($DEBUG);
print "Time: $time\n" if ($DEBUG);

if ($logfile eq "")   {$logfile   = "/tmp/backupreport";}
if ($errorfile eq "") {$errorfile = "/tmp/errorlist";}
if ($retryfile eq "") {$retryfile = "/tmp/retryfilelist";}

print "Logfile: $logfile\n" if ($DEBUG);
print "Errorfile: $errorfile\n" if ($DEBUG);
print "Retryfile: $retryfile\n" if ($DEBUG);

my $numprocesses = 0 ;
my $t = new Proc::ProcessTable;
foreach my $p ( @{$t->table} ){
  if ( $p->cmndline =~ /\Q$command\E/ ) {
    unless ( $p->cmndline =~ /\Q$0\E/ ) {
      $numprocesses++ ;
    }
  }
}
print "Number of dsmc processes: $numprocesses\n" if ($DEBUG);
if ($numprocesses < 1){
  if(-f "/tmp/dsmc.restart"){
    $count=`cat /tmp/dsmc.restart`;
    $count = $count + 1;
  }else{
    $count=1;
  }
  if ($count > 2){
    print "CRITICAL: Cannot Restart dsmc after $count attempts\n" if($DEBUG);
    $answer = "CRITICAL: Cannot Restart dsmc after $count attempts";
    $state = 2;
  }else{
    if (-f "/etc/init.d/dsmc"){
      print "WARNING: no dsmc process. Restart Attempt $count\n" if ($DEBUG);
      $answer = "WARNING: no dsmc process. Restart Attempt $count";

####################################################
##    todo
##    need to add nagios to sudo to restart tivoli
##    $runDSMC=`sudo /etc/init.d/dsmc restart`;
####################################################

      open (FILE, ">/tmp/dsmc.restart");
      print FILE $count;
      close FILE;
      $state = 1;
    }else{
      print "CRITICAL :: No dsmc Startup Script Found\n" if ($DEBUG);
      $answer = "No /etc/init.d/dsmc Startup Script Found";
      $state = 2;
    }
  }
}else{
  if (-f "/tmp/dsmc.restart"){
    $remove_file=`rm /tmp/dsmc.restart`;
  }
  &check_active;
  if (-f "$logfile"){
    open (LOG, "$logfile");
    my @logs=<LOG>;
    close LOG;
    my $loglen = scalar(@logs);
    if ($loglen > 0){
      my $getTransferred = `grep "transferred" $logfile`;
      my $getFailed = `grep "failed" $logfile`;
      my $getBackedup = `grep "backed up" $logfile`;
      my @parseTransferred = split(" ", $getTransferred);
      my @parseFailed = split(" ", $getFailed);
      my @parseBackedup = split(" ", $getBackedup);
      $transferred = "$parseTransferred[7]"." $parseTransferred[8]";
      $failed = $parseFailed[7];
      $backedup = $parseBackedup[8];
      if ($failed > 0){
        $answer="$failed Failed Object(s) in $logfile";
        $state=1;
    }
  }
#  if (-f "$errorfile"){
#    open (ERROR, "$errorfile");
#    my @error=<ERROR>;
#    close ERROR;
#    my $errorlen=scalar(@error);
#    if ($errorlen > 0){
#        $erroroutput = " $errorlen files failed to backup ";
#        print "$erroroutput Files Failed To Backup\n" if ($DEBUG); 
#    }
#  }
#  if (-f "$retryfile"){
#    open (RETRY, "$retryfile");
#    my @retry=<RETRY>;
#    close RETRY;
#    my $retrylen=scalar(@retry);
#    if ($retrylen > 0){
#        $retryoutput = " $retrylen files are being retried ";
#        print "$retryoutput Files Are Being Resent\n" if ($DEBUG);
#    }
  }
}
print $answer;
exit ($state);

sub check_active(){
  $status = 1;
  my $isscheduled=`tail -20 $schedlog | grep "Server Window Start"`;
  if ($isscheduled ne ""){
    my @getstart = split(" ", $isscheduled);
    my $startlen=scalar(@getstart)-1;
    my $today2=$getstart[$startlen];
    chomp $today2;
    $today2=~s/\///g;
    my $runtime = $getstart[5];
    chomp $runtime;
    $runtime=~s/://g;
    $timeoffset = $time-$runtime;
    my $t1=$time-$runtime;
    if ($today2 eq $today1){
      if ($runtime > $time){
        print "OK: backup process Completed and is scheduled properly\n" if ($DEBUG);
        $answer = "OK: Backup Completed Successfully and is scheduled properly";
        $state = 0;
      }else{  
        my $t2=$time-$runtime;
        $getstatus=`tail -1 $schedlog`;
        if ($getstatus eq ""){
            $getstatus=`tail -2 $schedlog | grep -v '^$'`;
        }
        if ($getstatus=~/Incremental/ || $getstatus=~/Processed/ || $getstatus=~/Normal/ || $getstatus=~/Successful/ || $getstatus=~/incremental/){
            print "OK: Backup is Running Correctly\n" if ($DEBUG);
            $answer="OK: Backup is Running Correctly";
            $state=0;
        }elsif($timeoffset < 120000){  #### changed this to 120 minutes from 30 to handle cases where the logfile is empty during backup
            print "OK: Backup is Running. Waiting for Tivoli to Backfill the logfile timeoffset=$timeoffset\n" if ($DEBUG);
            $answer="OK: Backup is Running. Waiting for Tivoli to Backfill the logfile timeoffset=$timeoffset";
            $state=0;
        }else{
            my $t4=$time-$runtime;
            print "CRITICAL: backup process exists, but next scheduled backup is in the past\n" if ($DEBUG);
            $answer = "CRITICAL: backup process exists, but next scheduled backup is in the past timeoffset=$timeoffset , time=$time , runtime=$runtime , getstatus=$getstatus";
            $state = 2;
        }
      }
    }elsif ($today2 eq $tomorrow1){
      print "OK: backup not running, has been scheduled properly\n" if($DEBUG);
      $answer = "OK: backup not running, has been scheduled properly";
      $state = 0;
    }elsif ($today2 eq $today1 && $runtime > $time){
      print "OK: backup not running, has been scheduled properly for later today\n" if($DEBUG);
      $answer = "OK: backup not running, has been scheduled properly for later today";
      $state = 0;
    }else{
      print "CRITICAL: Backup is not scheduled correctly\n" if ($DEBUG);
      $answer = "CRITICAL: Backup is not scheduled correctly";
      $state = 2;
    }
  }else{
    my $isactive=`tail -1 $schedlog`;
      chomp $isactive;
    if ($isactive eq ""){
      $blank="SECONDARY";
      $isactive=`tail -2 $schedlog | grep -v '^\$'`;
    }else{
      $blank="isactive not null";
    }
    if ($isactive=~/Normal File/){
      my @getdate = split(" ", $isactive);
      if ($getdate[0] eq "$today"){
        $getdate[1]=~s/://g;
        my $diff = $time-$getdate[1];
        if ($diff > 2500){
            print "CRITICAL: dsmc is running, last file was backed up > 25 Minutes ago\n" if($DEBUG);
            $answer =    "CRITICAL: dsmc is running, last file was backed up > 25 Minutes ago";
            $state = 2;
        }elsif($diff == 0 ){
            print "OK: Backup is currently running and transferring files\n" if($DEBUG);
            $answer =    "OK:Backup is Transferring Files";
            $state = 0;
        }elsif($diff > 100 && $diff < 2500){
            print "WARNING: backup finished, waiting to receive the schedule\n" if($DEBUG);
            $answer ="WARNING: backup finished, waiting to receive the schedule";
            $state = 1;
        }else{
            print "OK: backup process is running normally\n" if($DEBUG);
            $answer =    "OK: backup process is running normally";
            $state = 0;
        }
      }else{
            my $timediff = 240000 - $getdate[1];
            my $diff = $time - $timediff;
            if ($diff > 2500 || $diff < 0 ){
            print "CRITICAL: last file backup up > 25 Minutes ago, no new schedule received\n" if ($DEBUG);
            $answer = "CRITICAL: last file backup up > 25 Minutes ago, no new schedule received";
            $state = 2;
            }else{
            print "OK: Backup is running normally\n" if ($DEBUG);
            $answer = "OK: Backup is running normally";
            $state = 0;
            }
      }      
    }elsif($isactive=~/End:/){
      my @getdate=split(" ", $isactive);
      if ($getdate[0] eq "$today"){
        my $diff = $time-$getdate[1];
        if ($diff > 2500){
            print "CRITICAL: last file backed up > 25 Mins ago, no new schedule received\n" if($DEBUG);
            $answer = "CRITICAL: last file backed up > 25 Mins ago, no new schedule received";
            $state = 2;
        }else{
            print "WARNING: backup finished, waiting to receive the new schedule\n" if($DEBUG);
            $answer = "WARNING: backup finished, waiting to receive the new schedule";
            $state = 1;
        }
      }else{
        my $timediff = 240000 - $getdate[1];
        my $diff = $time - $timediff;
        if ($diff > 2500 || $diff < 0){
            print "CRITICAL: last file backed up > 25 Mins ago, no new schedule received\n" if($DEBUG);
            $answer = "CRITICAL: last file backed up > 25 Mins ago, no new schedule received";
            $state = 2;
        }else{
            print "OK: waiting for the new backup schedule\n" if($DEBUG);
            $answer = "OK: waiting for the new backup schedule";
            $state = 0;
        }
      }  
    }elsif($isactive=~/Processed/){
      print "OK: Files are still being backed up--processed\n" if($DEBUG);
      $answer = "OK: files are still backing up--processed";
      $state = 0;
    }elsif($isactive=~/Sent/){
      print "OK: Files are still being backed up--sent\n" if($DEBUG);
      $answer = "OK: files are still backing up--sent";
      $state = 0;
    }elsif($isactive=~/incremental/){
      print "OK: Files are still being backed up--incremental\n" if($DEBUG);
      $answer = "OK: files are still backing up--incremental";
      $state = 0;
    }elsif($isactive=~/Successful/){
      print "OK: Files are still being backed up--successful\n" if($DEBUG);
      $answer = "OK: files are still backing up--successful";
      $state = 0;
    }else{
      print "CRITICAL: backup process has died\n" if($DEBUG);
      $answer = "CRITICAL: backup process has died";
      $state = 2;
    }
  }  
}

