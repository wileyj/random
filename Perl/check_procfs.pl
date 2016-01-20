#!/usr/bin/perl

use strict;
use Time::Local;
use POSIX;
use Getopt::Long;

my $stats_file="/tmp/procfs-stats";
my $localtime=time;
my %old_stats;
my %new_stats;
my %stored;
my $cacti;
my $switch;
my $pipe;
my $metric;
my $threshold;
my $debug;
my $help;
my $first_run;
my $empty;
my $metricName;
GetOptions ('cacti' => \$cacti, 'pipe' => \$pipe, 'switch' => \$switch, 'metric=s' => \$metric, 'threshold=s' => \$threshold, 'debug' => \$debug, 'help' => \$help);
if ($help){
  print "Usage: check_procfs.pl\n";
  print "\t-d = Show Debug Output\n";
  print "\t-c = Print Output for Cacti CPU Usage Graphing\n";
  print "\t-s = Print Output for Cacti CPU Context Switch Graphing\n";
  print "\t-p = Print Output for open Sockets,Files & Pipes\n";
  print "\t-m = Cpu Metric to check\n";
  print "\t\tMetrics:\n";
  print "\t\t\tuser\n";
  print "\t\t\tnice\n";
  print "\t\t\tsystem\n";
  print "\t\t\tidle\n";
  print "\t\t\tiowait\n";
  print "\t\t\tirq\n";
  print "\t\t\tsoft_irq\n";
  print "\t\t\tstolen\n";
  print "\t\t\tcontext\n";
  print "\t\t\tintr\n";
  print "\t-t = Threshold to check CPU Metric against\n";
  print "\t-h = This help message\n\n";
  exit 0;
}
if ($pipe){
  print "Doing work for Pipe/Socket/Files Data\n" if ($debug);
  &do_pipe;
}
if ($cacti || $switch){
  print "Found Cacti, Undefining metric $metric\n" if ($debug);
  undef $metric;
  undef $pipe;
}
if ($metric){
  undef $cacti;
  undef $switch;
  undef $pipe;
  $metricName=ucfirst $metric;
}
if (!$metric){
  if (!$cacti && !$switch && !$pipe){
    print "cacti:$cacti\n";
    print "switch:$switch\n";
    print "CRITICAL: No Pipe, Metric or Cacti option supplied\n";
    exit 2;
  }
}
if ($metric){
  chomp $metric;
  if (
       $metric eq "user" ||
       $metric eq "nice" ||
       $metric eq "system" ||
       $metric eq "idle" ||
       $metric eq "iowait" ||
       $metric eq "irq" ||
       $metric eq "soft_irq" ||
       $metric eq "context" ||
       $metric eq "intr" ||
       $metric eq "stolen"
  ){
    print "Using CPU Metric $metric\n" if ($debug);
    if (!$threshold){
      print "Threshold Not Found-Defaulting to 0\n" if ($debug);
      $threshold=0;
    }elsif($threshold=~/[a-zA-Z]/){
      print "THREShOLD is a char, not a num: $threshold\n" if ($debug);
      $threshold=0;
    }else{
      print "Using arg threshold:$threshold\n" if ($debug);
      $threshold=$threshold;
    }
  }else{
    print "CRITICAL: Incorrect CPU Metric supplied:$metric:";
    print "\n" if ($debug);
    exit 2;
  }    
}
        
if ($debug){
  print "Options:\n";
  print "\tcacti:\t$cacti\n";
  print "\tswitch:\t$switch\n";
  print "\tmetric:\t$metric\n";
  print "\tthresh:\t$threshold\n";
  print "\tdebug:\t$debug\n";
}

if (!-f $stats_file){
  system("touch $stats_file");
  $first_run=1;
}else{
  my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks) = stat($stats_file);
  if ($size < 76){
    $empty=1;
  }else{
    open(FILE, $stats_file);
    my @lines=<FILE>;
    close FILE;
    foreach my $item(@lines){
      chomp $item;
      my @split=split(":", $item);
      $old_stats{$split[0]}=$split[1];
    }
  }
}
open(OUT, ">$stats_file");
close OUT;
open (OUT, ">>$stats_file");

my $line=`head -1 /proc/stat`;
  chomp $line;
  print "Cpu Line: $line\n" if ($debug);
my $ctxt_line=`grep "ctxt" /proc/stat`;
  chomp $ctxt_line;
  print "Context Switch Line: $ctxt_line\n" if ($debug);
  my ($ctxt_name,$ctxt) = split(" ", $ctxt_line);
my $intr_line=`grep "intr" /proc/stat`;
  chomp $intr_line;
  my ($intr_name,$intr) = split(" ", $intr_line);

#cpu  79670799 0 138398240 16873901221 26829901 1729092 27566872 62622372                                                                            
my ($cpu, $user, $nice, $system, $idle, $iowait, $irq, $soft_irq, $stolen) = split(" ", $line);
my $total=$user+$nice+$system+$idle;
$new_stats{'user'}=$user;		print OUT "user:$user\n";
$new_stats{'nice'}=$nice;		print OUT "nice:$nice\n";
$new_stats{'system'}=$system;		print OUT "system:$system\n";
$new_stats{'idle'}=$idle;		print OUT "idle:$idle\n";
$new_stats{'iowait'}=$iowait;		print OUT "iowait:$iowait\n";
$new_stats{'irq'}=$irq;			print OUT "irq:$irq\n";
$new_stats{'soft_irq'}=$soft_irq;	print OUT "soft_irq:$soft_irq\n";
$new_stats{'context'}=$ctxt;		print OUT "context:$ctxt\n";
$new_stats{'intr'}=$intr;		print OUT "intr:$intr\n";
$new_stats{'stolen'}=$stolen;		print OUT "stolen:$stolen\n";
$new_stats{'total'}=$total;		print OUT "total:$total\n";
$new_stats{'localtime'}=$localtime;	print OUT "localtime:$localtime\n";

if ($first_run == 1 && !$cacti){
  print "CRITICAL: Created $stats_file\n";
  exit(2);
}
if ($empty == 1 && !$cacti){
  print "CRITICAL: $stats_file is empty\n";
  exit(2);
}

print "*********************************\n" if ($debug);
print "CURRENT STOLEN:\t\t$stolen\n" 	if ($debug);
print "CURRENT USER:\t\t$user\n" 	if ($debug);
print "CURRENT SYSTEM:\t\t$system\n" 	if ($debug);
print "CURRENT NICE:\t\t$nice\n" 	if ($debug);
print "CURRENT IDLE:\t\t$idle\n" 	if ($debug);
print "CURRENT IOWAIT:\t\t$iowait\n" 	if ($debug);
print "CURRENT IRQ:\t\t$irq\n" 		if ($debug);
print "CURRENT SOFT IRQ:\t$soft_irq\n" 	if ($debug);
print "CURRENT CTXT SWITCH:\t$ctxt\n"	if ($debug);
print "CURRENT INTERRUPTS:\t$intr\n"	if ($debug);
print "CURRENT TOTAL:\t\t$total\n" 	if ($debug);
print "CURRENT TIME:\t\t$localtime\n" 	if ($debug);
print "\n" if ($debug);
print "PREVIOUS STOLEN:\t$old_stats{'stolen'}\n" 	if ($debug);
print "PREVIOUS USER:\t\t$old_stats{'user'}\n" 		if ($debug);
print "PREVIOUS SYSTEM:\t$old_stats{'system'}\n" 	if ($debug);
print "PREVIOUS NICE:\t\t$old_stats{'nice'}\n" 		if ($debug);
print "PREVIOUS IDLE:\t\t$old_stats{'idle'}\n" 		if ($debug);
print "PREVIOUS IOWAIT:\t$old_stats{'iowait'}\n" 	if ($debug);
print "PREVIOUS IRQ:\t\t$old_stats{'irq'}\n" 		if ($debug);
print "PREVIOUS SOFT IRQ:\t$old_stats{'soft_irq'}\n" 	if ($debug);
print "PREVIOUS CTXT SWITCH:\t$old_stats{'context'}\n"	if ($debug);
print "PREVIOUS INTERRUPTS:\t$old_stats{'intr'}\n"	if ($debug);
print "PREVIOUS TOTAL:\t\t$old_stats{'total'}\n" 	if ($debug);
print "PREVIOUS TIME:\t\t$old_stats{'localtime'}\n" 	if ($debug);
print "*********************************\n\n" if ($debug);

$stored{'localtime'}=$new_stats{'localtime'}-$old_stats{'localtime'};
$stored{'total'}=$new_stats{'total'}-$old_stats{'total'};
$stored{'stolen'}=$new_stats{'stolen'}-$old_stats{'stolen'};
$stored{'user'}=$new_stats{'user'}-$old_stats{'user'};
$stored{'system'}=$new_stats{'system'}-$old_stats{'system'};
$stored{'idle'}=$new_stats{'idle'}-$old_stats{'idle'};
$stored{'nice'}=$new_stats{'nice'}-$old_stats{'nice'};
$stored{'context'}=$new_stats{'context'}-$old_stats{'context'};
$stored{'intr'}=$new_stats{'intr'}-$old_stats{'intr'};

my $percent=substr(($stored{$metric}/$stored{'total'})*100,0,4);

my $percent_user=ceil(($stored{'user'}/$stored{'total'})*100);
my $percent_nice=ceil(($stored{'nice'}/$stored{'total'})*100);
my $percent_system=ceil(($stored{'system'}/$stored{'total'})*100);
my $percent_idle=ceil(($stored{'idle'}/$stored{'total'})*100);
my $percent_iowait=ceil(($stored{'iowait'}/$stored{'total'})*100);
my $percent_irq=ceil(($stored{'irq'}/$stored{'total'})*100);
my $percent_soft_irq=ceil(($stored{'soft_irq'}/$stored{'total'})*100);
my $percent_stolen=ceil(($stored{'stolen'}/$stored{'total'})*100);

if ($cacti && !$switch){
  print "Printing CPU Usage data for Cacti\n" if ($debug);
  print "user:$percent_user nice:$percent_nice system:$percent_system idle:$percent_idle iowait:$percent_iowait irq:$percent_irq soft_irq:$percent_soft_irq stolen:$percent_stolen";
  print "\n" if ($debug);
  exit 0;
}
if ($switch && !$cacti){
  print "Printing CPU Context Switch/Interrupt data for Cacti\n" if ($debug);
  print "context:$stored{'context'} intr:$stored{'intr'}";
  print "\n" if ($debug);
  exit 0;
}
if ($metric eq "context"){
  print "Nagios Context Switch output:\n" if ($debug);
  if ($stored{$metric} eq ""){
    print "WARNING:No Context Switches Recorded";
    exit 1;
  }else{
    if ($stored{$metric} <= $threshold){
      print "OK: Context Switches=$stored{$metric} in $stored{'localtime'}/s";
      exit 0;
    }else{
      print "CRITICAL: Context Switches=$stored{$metric} in $stored{'localtime'}/s";
      exit 2;
    } 
  } 
}
if ($metric eq "intr"){
  print "Nagios Interrupts output:\n" if ($debug);                                                                                                        
  if ($stored{$metric} eq ""){                                                                                                                                
    print "WARNING:No Interrupts Recorded (NULL)";                                                                                                             
    exit 1;                                                                                                                                                   
  }else{                                                                                                                                                      
    if ($stored{$metric} <= $threshold){                                                                                                                      
      print "OK: Interrupts Switches=$stored{$metric} in $stored{'localtime'}/s";
      exit 0;                                                                                                                                                 
    }else{
      print "CRITICAL: Interrupts Switches=$stored{$metric} in $stored{'localtime'}/s";
      exit 2;                                                                                                                                                 
    } 
  }
}
print "Time since last run: $stored{'localtime'} seconds\n" if ($debug);
print "Aggregate Total: $stored{'total'}\n" if ($debug);
print "Aggregate $metric: $stored{$metric}\n" if ($debug);
print "Aggregate Percentage: $percent\%\n" if ($debug);

if ($stored{$metric} eq ""){
  print "CRITICAL: CPU $metricName Data is unreadable";
  print "$metric:$stored{$metric}\n" if ($debug);
  exit 2;
}elsif ($stored{$metric} == 0 && 0 <= $threshold){
  print "OK: $metricName CPU: $percent in $stored{'localtime'}/s";
  exit 0;
}elsif(!$stored{'localtime'}){
  print "CRITICAL: Time Data is unreadable";
  exit 2;
}else{
  if ($percent > $threshold && $stored{'localtime'} > 0){
    print "$percent > $threshold\n" if ($debug);
    print "CRITICAL: $metricName CPU Time - $percent\% in $stored{'localtime'}/s";
    exit 2;
  }elsif($percent > $threshold && $stored{'localtime'} == 0){
    print "$percent > $threshold\n" if ($debug);
    print "WARNING: Time Elapsed is 0, Wait longer.$metricName: $percent\%";
    exit 1;
  }elsif($percent == $threshold && $stored{'localtime'} == 0){
    print "$percent == $threshold\n" if ($debug);
    print "WARNING: Time Elapsed is 0, Wait longer.$metricName: $percent\%";
    exit 1;
  }elsif($percent <= $threshold && $stored{'localtime'} > 0){
    print "$percent <= $threshold\n" if ($debug);
    print "OK: $metricName CPU: $percent\% in $stored{'localtime'}/s";
    exit 0;
  }else{
    print "UNKNOWN: Data is unreadable";
    exit 3;
  }
}
sub do_pipe{
  print "Inserted into do_pipe\n" if ($debug);
  #sleep 5;
  my $files=`cat /proc/sys/fs/file-nr|cut -f1`;
    chomp $files;
  print "Open Files: $files\n" if ($debug);
  my $pipes=`lsof -Ft 2>&1 | grep FIFO | wc -l`;
    chomp $pipes;
  print "Open Pipes: $pipes\n" if ($debug);
  my $tcp=`netstat -anp | grep tcp | wc -l`;
    chomp $tcp;
  print "Open TCP Sockets: $tcp\n" if ($debug);
  my $udp=`netstat -anp | grep udp | wc -l`;
    chomp $udp;
  print "Open UDP Sockets: $udp\n" if ($debug);
  my $unix=`netstat -anp | grep unix | wc -l`;
    chomp $unix;
  print "Open Unix Sockets: $unix\n" if ($debug);
  #echo -n "files:$files pipes:$pipes tcp:$tcp udp:$udp unix:$unix" > /tmp/sockets_pipes_files.tmp 
  print "files:$files pipes:$pipes tcp:$tcp udp:$udp unix:$unix";
  exit 0;
}
