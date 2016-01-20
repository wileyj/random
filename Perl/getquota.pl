#!/usr/bin/perl
use POSIX;
use Getopt::Long;

$hostname=`hostname`;
chomp $hostname;
if ($hostname ne "shared-nfs-001.use1.local.com"){
  print "Script must be run on shared-nfs-001.use1.local.com. exiting\n";
  exit 1;
}
if (!-d "/homeroot" ){
  print "No /homeroot found. exiting\n";
  exit 1;
}
Getopt::Long::Configure ("no_ignore_case");
GetOptions(
  'percent|p=s' => \$percent,
  'user|u=s'    => \$user,
  'help|h'    => \$help
);

if ($help){
print"
Usage: getquota
Options:
        --percent   (-p) Display all Users that are n % over the quota limit
        --user      (-u) Display the report for a specific user only
        --help      (-h) Displays this Message

  Note: you can specify a user & percentage at the same time
";
exit;
}
if ($percent){
  $title = " ALL USERS $percent"."%"." OVER SOFT QUOTA LIMIT ";
  if ($user){
    $title = " Quota REPORT for $user -- $percent"."%"." OVER SOFT QUOTA LIMIT ";
  }
}else{
  $percent = 0;
  $title=" ALL USERS OVER SOFT QUOTA LIMIT ";
  if ($user){
    $title=" Quota REPORT for $user ";
  }  
}
$getRepquota = `/usr/sbin/repquota /homeroot`;
@returned = split("\\n", $getRepquota);
print "\n
*** $title ***
\n\n";
print "$returned[0]\n";
print "$returned[1]\n";
print "$returned[2]\n";
print "$returned[3]\n";
print "$returned[4]\n";
$len=scalar(@returned);
for ($i=0;$i<$len+1;$i++){
  $line=$returned[$i];
  @split=split(" ", $line);
  if ($user && $split[0] eq $user){
    $found_user = 1;
  }
  if ($split[1] =~/\+/){
    $div = $split[2] / $split[3];
    $actualPercentage=$div * 100;
    @getDecimal=split("\\.", $actualPercentage);
    $substr = substr($getDecimal[1], 0,2);
    if (substr($getDecimal[1],0,2) < 50){
      $actualPercentage=floor($actualPercentage);
    }else{
      $actualPercentage=ceil($actualPercentage);
    }
    $percentOver = $actualPercentage - 100;
    if ($percentOver >= $percent){
      #print "OVER $split[0] $split[1] $split[2] $split[3] $split[4]  Perc: $actualPercentage percentOver: $percentOver\n";
       if ($user){
         if ($split[0] eq $user){print "$line\n";$found = 1;}
       }else{
         print "$line\n";
       }
    }
  }
}
if ($user && $found_user ==1 && $found != 1){
  print "*** User $user Not Over Quota Limit ***\n";
}
if ($user && $found_user != 1){
  print "*** User $user was not found ***\n";
}
print "\n\n";
exit 0;
