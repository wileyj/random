#!/usr/bin/perl
use Proc::ProcessTable;
use IPC::Open3 qw( open3 );
use POSIX ":sys_wait_h";

$timestamp=localtime;
my @cmds=(
  "perl /tmp/test2.pl > /tmp/outfile1.txt",
  "perl /tmp/test2.pl > /tmp/outfile2.txt",
  "perl /tmp/test2.pl > /tmp/outfile3.txt"
);
sub launch {
   open(local *CHILD_STDIN, '<', '/dev/null') or die $!;
   return open3('<&CHILD_STDIN', '>&STDOUT', '>&STDERR', @_);
}

my %children;
for my $cmd (@cmds) {
   print "Command $cmd started at "."$timestamp"."\n";
   my $pid = launch($cmd);
   $children{$pid} = $cmd;
}
$count = 0;
while (%children) {
  foreach $item(sort keys %children){
    print "\nchecking process $item\n";
    sleep 2;
    $pid = waitpid(-1, &WNOHANG);
    if ($pid == -1) {}
    elsif (WIFEXITED($?)) {
      print "Process $pid exited.\n";
      $cmd = delete($children{$item});
      print "Command $cmd ended at "."$timestamp"." with \$? = $?"."\n";
    }else{
      print "False alarm on $pid.\n";
    }
    $num = checkProcess($item);
    print "num: $num\n";
    if ($num == 0){
      my $cmd = delete($children{$item});
      print "Command $cmd ended at "."$timestamp"." with \$? = $?"."\n";
    }
  }
}
sub checkProcess{
  $pid = $_[0];
  my $numprocesses = 0 ;
  my $t = new Proc::ProcessTable;
  foreach my $p ( @{$t->table} ){
    if ( $p->pid=~ /\Q$pid\E/ ) {
      $this=$p->cmndline;
      print "cmndline: $this\n";
      unless ( $p->cmndline=~ /\Q<defunct>\E/ ) {
        $numprocesses++ ;
      }
    }
  }
  print "numprocess: $numprocesses\n";
  return $numprocesses;
}