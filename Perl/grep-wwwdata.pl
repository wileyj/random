#!/usr/bin/perl

use POSIX;
$date=time();

$emaillist="user\@local.com";

opendir (DIR, "/dir/data");
@dir = readdir DIR;
close DIR;

foreach $dir(@dir){
  chomp $dir;
  unless ($dir eq "." || $dir eq ".." || $dir eq ".snapshot" ){
    $path="/www/data/"."$dir";
    if (-d $path && !-l $path){
      $output_file="/tmp/find/"."$dir".".findoutput";
      if (-f $output_file){
        open (FILE, ">$output_file");
        close FILE; 
      }
      print "outputfile: $output_file\n";
      system("/usr/bin/find $path -type f \\( -name \"*.pl*\" -o -name \"*.sh*\" -o -name \"*.mp4.*\" -o -name \"*.ksh*\" -o -name \"*.php*\" -o -name \"*.exe*\" -o -name \"*.js*\" \\)  -and \\( ! -path \"*template*\" -and ! -path \"*.snapshot*\" -and ! -path \"*wp-content*\" -and ! -path \"*smarty*\" -and ! -path \"*themes*\" -and ! -path \"*plugin*\" -and ! -path \"*fb_personality_quiz*\" -and ! -path \"/www/data/services.nick.com/nick/member*\"  -and ! -path \"*flux-gs.php\" -and ! -path \"*yml.php\" -and ! -path \"/www/data/appdynamics/*\" -and ! -path \"/www/data/evolven/agent*\" \\) >> $output_file\n");
    }
  }
}
opendir (DIR, "/tmp/find");
@dir=readdir DIR;
closedir DIR;
    $statfile="/tmp/saved/"."stat-file."."$date";
    $emailfile="/tmp/saved/emailfile";
    $rm_file="/tmp/saved/rm-files.sh";
    open (EMPTY, ">$rm_file");
    close EMPTY;
    open (EMPTY, ">$emailfile");
    close EMPTY;
    open (OUT, ">>$statfile");
    open (RM, ">>$rm_file");
    open (EMAIL, ">>$emailfile");

foreach $item(@dir){
  chomp $item;
  $file_path="/tmp/find/"."$item";
  unless ($item eq "." || $item eq ".."){
    open (FILE, "$file_path");
    @lines=<FILE>;
    close FILE;
    if (!-d "/tmp/saved"){
      print "mkdir /tmp/saved\n";
      system("mkdir /tmp/saved");
    }
    foreach $line(@lines){
      chomp $line;
      if (-f $line){
        $line=~s/\ /\\\ /g;
        $stat=`stat $line`;
        print OUT "$line\n";
        print OUT "$stat\n";
        @split=split(/\//,$line);
        $len=scalar(@split);
        $dirpath="/tmp/saved/"."$split[3]";
        if (!-d $dirpath){
          print "mkdir $dirpath\n";
          system("mkdir $dirpath");
        }
        $newfile="$dirpath"."/"."$split[$len-1]"."."."$date";
        $newfile=~s/\ /\\\ /g;
        $get_file="";
        $get_file=`file $line`;
        if (
		$get_file =~/MS Windows/ || 
		$get_file =~/shell script/ || 
		$get_file =~/perl script/ ||
		$get_file =~/PHP script/ ||
		$get_file =~/ASCII text/
        ){
        #if ($get_file =~/Bourne/ || $get_file =~/PHP/ || $get_file =~/perl/){
          print RM "cp -p $line $newfile\n";
          #system("cp -p $line $newfile");
          print RM "rm -f $line\n";
          #system("rm -f $line");
          $ls_file=`ls -l $line`;
          print EMAIL "$ls_file";
        }
          #$ls_file=`ls -l $line`;
          #print EMAIL "$ls_file";
      }
    }
  }
}
close EMPTY;
close OUT; 
close EMAIL;
system("/bin/mailx -s \"Scan of /dir/data\" $emaillist < $emailfile");
