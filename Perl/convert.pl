#!/usr/bin/perl

use Getopt::Long;
GetOptions ('debug' => \$debug, 'input=s' => \$input, 'output=s' => \$output);
print "Innput Dir: $input\n" if ($debug);
print "Output Dir: $output\n" if ($debug);
$input_fix=$input;
$output_fix=$output;
$input_fix=~s/\ /\\ /g;
$output=~s/\ /\\ /g;
print "Escaped Input: $input_fix\n" if ($debug);
print "Escaped Output: $output_fix\n" if ($debug);

if (!$input){
  print "No Input Dir specified...Exiting\n";
  exit 1;
}elsif(!$output){
  print "No Output dir specified...Exiting\n";
  exit 1;
}else{
  &run();
}
sub run{
  if (-d "$input" && -d "$output"){
    system ("ls $input_fix") if ($debug);
    print "Reading Dir $input\n" if ($debug);
    opendir (DIR, $input);
    @dir = readdir DIR;
    closedir DIR;
    foreach $item(@dir){
      print "Reading file $item\n" if ($debug);
      if ($item=~/.avi/  || $item=~/.mp4/ || $item=~/.mkv/ || $item=~/.mpg/ ){
    	$item=~s/\(/\\(/g;
    	$item=~s/\)/\\)/g;
    	$item=~s/\'/\\'/g;
    	$item=~s/\!/\\!/g;
    	$item=~s/\,/\\,/g;      
    	$item=~s/\ /\\ /g;      
        $avi=$item;
        $m4v=$item;
        if ($item=~/.avi/){
          $m4v=~s/.avi/.m4v/g;
        }elsif($item=~/.mp4/){
          $m4v=~s/.mp4/.m4v/g;
        }else{
          $m4v=~s/.mkv/.m4v/g;
        }
        $avi_file="$input_fix"."/"."$avi";
        $m4v_file="$output_fix"."/"."$m4v";
        unless ($item=~/sample/ || $item=~/SAMPLE/){
          print "Converting $avi_file...\n";
          print "Saving as $m4v_file\n";
          #system("/Applications/HandBrakeCLI -i $avi_file -o $m4v_file --preset=\"digital\"");
          system("/Applications/HandBrakeCLI -i $avi_file -o $m4v_file --preset=\"AppleTV\"");
          print "Completed $m4v\n\n";
        }
      }
    }
  }else{
    if (-d $input){
      print "Output Dir $output is not a real dir\n";
    }else{
      print "Input Dir $input is not a real dir\n";
    }
    exit 1;
  }
}

