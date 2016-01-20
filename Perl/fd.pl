#!/usr/bin/perl
#1 get pid of nscd
#2 lsof the pid, get count of open files
#24179 ?        Ssl    0:05 /usr/sbin/nscd
use Getopt::Long ;
GetOptions ('debug' => \$debug, 'process=s' => \$process, 'cacti' => \$cacti, 'fd' => \$check_fd, 'help' => \$help);
if ($debug){
  $debug = 1;
}
if (!$process){
  $process="/usr/sbin/nscd";
}
$get_total_fd=`cat /proc/sys/fs/file-max`;
$get_current_fd=`/usr/sbin/lsof | wc -l`;
if ($check_fd){
  print "check_fd:$check_fd\n";
  $fd_remaining=$get_total_fd-$get_current_fd;
  print "Remaining FD's: $fd_remaining\n";
  exit 0;
}

print "process=$process\n";
$getPid=`ps xa | grep $process | grep -v grep | grep -v fd.pl`; 
if ($getPid ne ""){
  print ":$getPid:\n";
  ($pid, $null, $null, $cpu_time, $process)=split(" ", $getPid);
  print "pid: $pid\nn";
  print "cpu_time: $cpu_time\n";
  print "process: $process\n";
  eval {
    local $SIG{ALRM} = sub {die "alarm\n"};
    alarm 10;
    $lsof=`/usr/sbin/lsof -a -p $pid | wc -l`; 
    alarm 0;
  };
  if ($@) {
    die unless $@ eq "alarm\n";
    print "\"/usr/sbin/lsof -a -p $pid | wc -l\" Timed Out\n";
  }else {
    print "lsof command returned correctly\n" if ($debug);
  }
  chomp $lsof;
  print "lsof: $lsof file handles open by $process\n";
}else{
  print "No process running for $process\n";
  exit 0;
}



if ($process =~/nscd/ && $getPid ne ""){
  print "nscd=true\n";
  eval {
    local $SIG{ALRM} = sub {die "alarm\n"};
    alarm 10;
    $nscd_g=`/usr/sbin/nscd -g > /tmp/nscd_g.out`;
    alarm 0;
  };
  if ($@) {
    die unless $@ eq "alarm\n";
    print "\"/usr/sbin/nscd -g > /tmp/nscd_g.out\" Timed Out\n";
  }else {
    print "nscd -g command returned correctly\n" if ($debug);
  }
  print "nscd -g return code: $?\n";
  system("ls -al /tmp/nscd_g.out");
  open (FILE, "/tmp/nscd_g.out");  
  @lines=<FILE>;
  close FILE;
#  $externalHash{$userid}={
#        'userid'       => "$userid",
#        'contact_name' => "$fullname",
#        'email'        => "$useremail",
#        'ftpaccess'    => "$ftpaccess",
#        'shell'        => "$shell",
#        'warnspace'    => "$warnspace",
#        'hardspace'    => "$hardspace",
#        'warncount'    => "$warncount",
#        'hardcount'    => "$hardcount",
#        'retention'    => "$retention",
#        'islocked'     => "$islocked",
#        'shared'       => "",
#        'current'      => "$duHash{$userid}{'used'}"
#      }; 
  foreach $line(@lines){
    if ($line =~/:/){
      ($name, $null)=split(" ", $line);
      print "name:$name\n";
    }else{
      print "line:$line\n";
    }
    
  }
}
