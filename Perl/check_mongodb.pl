#!/usr/bin/perl

use strict;
use POSIX;
use Getopt::Long;
my $debug;
my $version;
my $options;
my $help;
my $mongo_path;
my $initial1;
my $initial2;
my $initial3;
my $runCMD;
my %mongoHash;

GetOptions ('debug' => \$debug, 'version=s' => \$version, 'options=s' => \$options, 'help' => \$help);
if ($debug){
  $debug = 1;
}
if ($help){
  &showHelp;
  exit 0;
}
if (!$version){
  print "No mongo version specified. Trying to Find Running version\n" if ($debug);
  $runCMD=`ps -ef | grep -i mongo | grep "mongod -f" | awk '{print $8'} | grep -v grep`;
  #print "Command: ps -ef | grep -i mongo | grep \"mongod -f\" | awk '{print \$8'} | grep -v grep\n" if ($debug);
  print "Found Process: $runCMD\n" if ($debug);
  my @split=split("/", $runCMD);
  $version=$split[4];
}
print "Setting version to $version\n" if ($debug);
$mongo_path="/opt/mongodb/product/"."$version"."/mongo";
my $cmd="echo \"db._adminCommand({serverStatus:1, repl:2})\" | $mongo_path";
print "Running command: echo \"db._adminCommand({serverStatus:1, repl:2})\" | $mongo_path\n" if ($debug);
my $run_cmd=`$cmd`;

#print "OUTPUT: $run_cmd\n" if ($debug);
#      $instance_data{$instance_name}={
#        'instance_name'    =>  $instance_name,
#        'instance_config'  =>  $config_file,
#        'pid'              =>  $pid,
#        'product_version'  =>  $product_version
#      };

my @lines=split("\n", $run_cmd);
my $len=scalar(@lines);
print "Output Length: $len\n\n" if ($debug);
my $block = 0;
my $count=0;
my $hashref;
for (my $i=3;$i<$len;$i++){
  $lines[$i]=~s/\"//g;
  if ($lines[$i]=~/:/){
    if ($lines[$i] =~/: {/){
      $block=1;
      $lines[$i]=~s/\s//g;
      $lines[$i]=~s/:\{//g;
      $hashref=$lines[$i];
    }
    $lines[$i]=~s/,//g; 
    my @split=split(" : ", $lines[$i]);
    my $keyref=$split[0];
      $keyref=~s/\s//g;
    my $keyval=$split[1];
    if ($hashref eq ""){
      $hashref="global";
    }
    if ($keyval ne ""){
      chomp $keyval; 
      $initial1=substr($hashref,0,1);
      if ($keyref eq "last_finished" || $keyref eq "missRatio" || $keyref eq "lockTime" || $keyref eq "uptimeEstimate" || $keyref eq "totalOpen"){
        $initial2=substr($keyref,0,1);
        $initial3=substr($keyref,-1,1);
      }else{
        $initial2=substr($keyref,0,1);
        $initial3=substr($keyref,1,1);
      }
      my $initials="$initial1"."$initial2"."$initial3";
      $mongoHash{$initials}={
        'section' => $hashref,
        'item'    => $keyref,
        'value'   => $keyval  
      };
      #print "$initials :: $hashref :: $keyref :: $keyval\n";
    }
  }
}
if ($options){
  print "Parsing Options: $options\n" if ($debug);
  my @getOpt=split(",", $options);
  foreach my $item(@getOpt){
    if ($mongoHash{$item}){
      print "$item".":"."$mongoHash{$item}->{'value'} ";
    }else{
      if ($item eq "rla"){
        print "$item".":"."0 ";
      }
    }
  }
}else{
  foreach my $item(sort keys %mongoHash){
    print "$mongoHash{$item}->{'section'}"."->"."$mongoHash{$item}->{'item'}".": $mongoHash{$item}->{'value'}\n";                                                                                                                               
  }  
}

sub showHelp(){
print "usage: check_mongo.pl <options>";
print "\t-h : help\n";
print "\t-d : debug messages\n";
print "\t-v : version - version of mongodb to use (optional)\n";
print "\t-o : options - comma separated list of options to return:
		ams = asserts -> msg
		aok = asserts -> ok
		are = asserts -> regular
		aro = asserts -> rollovers
		aus = asserts -> user
		awa = asserts -> warning
		bav = backgroundFlushing -> average_ms
		bfl = backgroundFlushing -> flushes
		bla = backgroundFlushing -> last_ms
		bld = backgroundFlushing -> last_finished
		bto = backgroundFlushing -> total_ms
		bac = btree -> accesses
		bhi = btree -> hits
		bmi = btree -> misses
		bmo = btree -> missRatio
		bre = btree -> resets
		cav = connections -> available
		ccu = connections -> current
		cre = currentQueue -> readers
		cto = currentQueue -> total
		cwr = currentQueue -> writers
		ccl = cursors -> clientCursors_size
		cti = cursors -> timedOut
		ctn = cursors -> totalOpen
		ehe = extra_info -> heap_usage_bytes
		eno = extra_info -> note
		epa = extra_info -> page_faults
		gle = globalLock -> lockTime
		gra = globalLock -> ratio
		gto = globalLock -> totalTime
		glo = global -> localTime
		gue = global -> uptimeEstimate
		gup = global -> uptime
		gve = global -> version
		mbi = mem -> bits
		mma = mem -> mapped
		mre = mem -> resident
		msu = mem -> supported
		mvi = mem -> virtual
		oco = opcounters -> command
		ode = opcounters -> delete
		oge = opcounters -> getmore
		oin = opcounters -> insert
		oqu = opcounters -> query
		oup = opcounters -> update
		rin = repl -> info
		ris = repl -> ismaster
		rla = repl -> lagSeconds\n";
}

