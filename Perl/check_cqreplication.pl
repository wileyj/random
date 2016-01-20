#!/usr/bin/perl
# perl check_cqreplication.pl -user admin -pass <pass> -site bet-cqpublish-009.811.mtvi.com -port 4503 -operation bundle -i bet-cqpublish-009 
# perl check_cqreplication.pl -eventhandler -user admin -pass <pass>

use HTML::Parser;
use JSON;
use strict;
use POSIX;
use Getopt::Long;
my $output= "/tmp/replication_failures.txt";
open (FILE, ">$output");
close FILE;
open (OUT, ">>$output");
my $debug;
my $user;
my $pass;
my $help;
my $instance;
my $port;
my $site;
my $text;
my $host;
my %hash;
my $operation;
my $json_root;
my $string;
my $exit_code;
my $total_failures = 0 ;
my $total_hosts = 0;
my $critical_ids;
my $warn_ids;
my $ok;
my $critical;
my $warning;
my $unknown;
my $list_hosts;
my $critical = 0;
my $warning = 0;
my $disabled = 0;
my $disabled_hosts;
my $fixed_bundle_return = 0;
my $eventhandler;
my $substr_num;
my $readfile = "/var/tmp/bundle_start_count.out";
my %s_count;
my $b_reset = 3600; # 1 hour to discard failed bundle count
my $alarm_return;
my @expected=(
  "11", 
  "61", 
  "51", 
  "138"
);


my $sanity;
GetOptions (
  'debug'            => \$debug,
  'help'             => \$help,
  'user=s'           => \$user,
  'pass=s'           => \$pass,
  'port=s'           => \$port,
  'instance=s'       => \$instance,
  'operation=s'      => \$operation,
  'site=s'           => \$site,
  'eventhandler'     => \$eventhandler
);
my $h_port;
my $h_name=`hostname`; chomp $h_name;
if ($h_name=~/author/){
  $h_port = "4502";
  $substr_num = "16";
}else{
  $h_port="4503";
  $substr_num = "17";
}
my $h_short = substr($h_name,0,$substr_num);
if (!$user && !$pass && !$port && !$instance && !$operation && !$site){
  $eventhandler = 1;
  $operation    = "bundle";  
  $user         = "admin";
  $pass         = "nowis2morrow";
  $port         = $h_port;
  $instance     = $h_name;
  $site         = $h_short; 
}
if ($eventhandler){
  if (!$user){
    $user = "admin";
  }
  if (!$pass){
    $pass = "nowis2morrow";
  }
  $operation    = "bundle";
  $eventhandler = 1;
  $port         = $h_port;
  $instance     = $h_name;
  $site         = $h_short;
}
if ($help){
  logger("Usage: $0 <options>\n",0);
  logger("options:\n",0);
  logger("\tuser         => <username> (ex: -u sysmgr)\n", 0);
  logger("\tpass         => <password> (ex: -p password)\n", 0);
  logger("\tsite         => <cq server> (ex: bet-cqauthor-001.811.mtvi.com\n",0);
  logger("\tport         => <cq server port> (ex: 4502 for author, 4503 for publish)\n", 0);
  logger("\toperation    => replication | bundle\n", 0);
  logger("\tinstance     => <instance> (ex: -i bet-cqpublish-001\n", 0);
  logger("\teventhandler => -e to run as eventhandler and fix bundles\n", 0);
  logger("\tdebug => prints debug output\n", 0);
  logger("\t\nEx:\n",0);
  logger("\t$0 -u sysmgr -p password -s bet-cqauthor-001.811.mtvi.com -o replication\n", 0);
  logger("\t$0 -u sysmgr -p password -i bet-cqpublish-001 -s bet-cqauthor-001.811.mtvi.com -o replication\n", 0);
  logger("\t$0 -eventhandler -user admin -pass <pass>\n",0);
  exit 0;
}
if (!$operation){
  logger("CRITICAL - missing operation option (replication|bundle)\n", 0);
  exit 2;
}
if ($operation ne "replication" && $operation ne "bundle"){
  logger("CRITICAL - operation needs to be either (replication|bundle)\n",0);
  exit 2;
}
if (!$user || !$pass || !$site){
  logger("CRITICAL - Error executing script, missing arguments\n", 0);
  exit 2;
}
logger("Operation == $operation\n", 1);

if ($operation eq "bundle"){
  my $path="/system/console/bundles/.json";
  my $base_url="http://"."$site".":"."$port"."$path";
  logger("Eventhandler: $eventhandler\n", 1);
  logger("Base Url: $base_url\n",1);
  $json_root="data";
  get_json($base_url, $user, $pass, $json_root);
}else{
  if ($instance){
    my $path = "/etc/replication/agents.author/"."$instance"."/jcr:content.queue.json";
    my $base_url="http://"."$site".":"."$port"."$path";
    logger("\tBase Url: $base_url\n",1);
    $text = $instance;
    $json_root="queue";
    get_json($base_url, $user, $pass, $json_root);
  }else{
    my $path="/etc/replication/agents.author.html";
    my $base_url="http://"."$site".":"."$port"."$path";
    my $url="$base_url -u"." $user".":"."$pass";
    logger("Url: $url\n",1);
    my $html = curl($base_url, $user, $pass);
    my @lines=split("\n", $html);
    foreach my $item(@lines){
      chomp $item;
      if ($item=~/cq-agent-header-on/ || $item=~/cq-agent-header-off/){
        $item=~s/<p><\/p><ul>//g;
        $item=~s/^\s+|\s+$//g;
        parse($item,"name");
      }
      if ($item=~/cq-agent-queue-idle/){
        $item=~s/<li><div class="li-bullet cq-agent-queue-idle">Queue is //g;
        $item=~s/<\/div><\/li>//g;
        $item=~s/^\s+|\s+$//g;
        parse($item,"queue");
      }
    }
  }
}
sub parse{
  my $html= $_[0];
  my $type= $_[1];
  my $parser = HTML::Parser->new(text_h => [\my @accum,  "text"]);
  $parser->parse($html);
  for (@accum){
    $text=$_->[0];
    if ($type eq "name"){
      my @get=split("\\(", $text);
      $text=$get[0];
      $host = $text;
    }
    if ($type eq "name"){    
      $text=~s/\ //g; 
      logger("Queue: $text\n",1);
      my $json_url="http://"."$site".":"."$port"."/etc/replication/agents.author/"."$text"."/jcr:content.queue.json";
      logger("\tJson Url: $json_url\n",1);
      $json_root="queue";
      get_json($json_url, $user, $pass, $json_root);
    }
  }
}
sub get_json{
  my $base_url  = $_[0];
  my $user      = $_[1];
  my $pass      = $_[2];
  my $json_root = $_[3];
  logger("\tjson_root: $json_root\n",1);
  my $url = "$base_url"." -u"." $user".":"."$pass";
  my $html = curl($base_url, $user, $pass);
  if ($html eq ""){
    exit 3;
  }
  my $decode = decode_json $html;
  if ($operation eq "replication"){
    do_replication($decode,$json_root);
  }else{
    do_bundles($decode,$json_root);
  }
}
sub do_replication{
  my $decode = $_[0];
  my $json_root = $_[1];
  foreach my $item( $decode) { 
    my $arrayref = $item->{$json_root};
    my $num   = scalar @$arrayref;
    logger("\tReplication failures: $num\n", 1);
    $total_failures = $total_failures+$num;
    $hash{$text}={
      'name'  => $text,
      'num'   => $num
    }; 
    my $qslastProcessTime = $decode->{'metaData'}{'queueStatus'}{'lastProcessTime'};
    my $qsprocessingSince = $decode->{'metaData'}{'queueStatus'}{'processingSince'};
    my $qsisBlocked       = $decode->{'metaData'}{'queueStatus'}{'isBlocked'};
    my $qsagentId         = $decode->{'metaData'}{'queueStatus'}{'agentId'};
    my $qstime            = $decode->{'metaData'}{'queueStatus'}{'time'};
    my $qsisPaused        = $decode->{'metaData'}{'queueStatus'}{'isPaused'};
    my $qsagentName       = $decode->{'metaData'}{'queueStatus'}{'agentName'};
    my $qsnextRetryPeriod = $decode->{'metaData'}{'queueStatus'}{'nextRetryPeriod'};
    logger("\tqslastProcessTime: $qslastProcessTime\n",1);
    logger("\tqsprocessingSince: $qsprocessingSince\n",1);
    logger("\tqsisBlocked: $qsisBlocked\n",1);
    logger("\tqsagentId: $qsagentId\n",1);
    logger("\tqstime: $qstime\n",1);  
    logger("\tqsisPaused: $qsisPaused\n",1);    
    logger("\tqsagentName: $qsagentName\n",1); 
    logger("\tqsnextRetryPeriod: $qsnextRetryPeriod\n",1);
    if($num > 0){
      logger("$text:\n",2);
      logger("\tqslastProcessTime: $qslastProcessTime\n",2);
      logger("\tqsprocessingSince: $qsprocessingSince\n",2);
      logger("\tqsisBlocked: $qsisBlocked\n",2);
      logger("\tqsagentId: $qsagentId\n",2);
      logger("\tqstime: $qstime\n",2);
      logger("\tqsisPaused: $qsisPaused\n",2);
      logger("\tqsagentName: $qsagentName\n",2);
      logger("\tqsnextRetryPeriod: $qsnextRetryPeriod\n",2);
    }
    if ($qsisBlocked eq "true"){
      logger("\tREPLICATION BLOCKED\n\n",1);
      $critical=1;
    }
    if (!$qsisBlocked && !$qstime){
      $disabled++;
      logger("REPLICATION DISABLED\n\n",1);
      if ($disabled > 1 ){
        $disabled_hosts = "$disabled_hosts".", "."$text";
      }else{
        $disabled_hosts = $text;
      }
    }
    if ($num > 0){
      $total_hosts++; 
      if ($total_hosts > 1 ){
        $list_hosts = "$list_hosts".", "."$text";
      }else{
        $list_hosts = $text;
      }
      for (my $i=0; $i<$num; $i++){
        my $id            = $item->{'queue'}->[$i]->{'id'};
        my $path          = $item->{'queue'}->[$i]->{'path'};
        my $time          = $item->{'queue'}->[$i]->{'time'};
        my $userid        = $item->{'queue'}->[$i]->{'userid'};
        my $type          = $item->{'queue'}->[$i]->{'type'};
        my $size          = $item->{'queue'}->[$i]->{'size'};
        my $lastProcessed = $item->{'queue'}->[$i]->{'lastProcessed'};
        my $numProcessed  = $item->{'queue'}->[$i]->{'numProcessed'};
        logger("Failed item: $i -- \n",1);
        logger("\tid: $id\n",1);
        logger("\tpath: $path\n",1);
        logger("\ttime: $time\n", 1);
        logger("\tuserid: $userid\n", 1);
        logger("\ttype: $type\n", 1);
        logger("\tsize: $size\n", 1);
        logger("\tlastProcessed: $lastProcessed\n", 1);
        logger("\tnumProcessed: $numProcessed\n", 1);
        my $human_number = $i+1;
        logger("Failed item: $human_number) \n",2);
        logger("\tid: $id\n",2);
        logger("\tpath: $path\n",2);
        logger("\ttime: $time\n", 2);
        logger("\tuserid: $userid\n", 2);
        logger("\ttype: $type\n", 2);
        logger("\tsize: $size\n", 2);
        logger("\tlastProcessed: $lastProcessed\n", 2);
        logger("\tnumProcessed: $numProcessed\n", 2);
      }
    }
    if ($disabled > 0){
      if ($critical != 1){
        $warning = 1;
      }
    }
  }
}
if ($operation eq "replication"){
  logger("Total_failures: $total_failures\n",1);
  logger("Hosts with failures: $list_hosts\n", 1);
  logger("Total_hosts: $total_hosts\n",1);
  logger("Disabled: $disabled\n", 1);
  logger("Disabled Hosts: $disabled_hosts\n",1);;
  logger("Critical: $critical\n",1);
  logger("Warn: $warning\n",1);
  if ($warning == 1 && $critical == 0){
    $string="WARNING - Replication disabled on: $disabled host ($disabled_hosts)";
    $exit_code=1;
  }elsif($warning == 0 && $critical == 1){
    $string="CRITICAL - $total_failures failures logged on $total_hosts host ( $list_hosts ) : check $output";
    $exit_code = 2;
  }elsif($warning == 0 && $critical == 0){
    $string="OK - All replication queues are clean";
    $exit_code = 0;
  }else{
    $string="Unknown Status";
    $exit_code = 3;
  }
  do_output($string, $exit_code);
}

sub do_bundles{
  my $decode = $_[0];
  my $json_root = $_[1];
  if (-f $readfile){
    my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks) = stat($readfile);
    if ($mtime >= $b_reset){
      open(BUNDLE, $readfile);
      my @lines=<BUNDLE>;                         
      close BUNDLE;                       
      foreach my $item(@lines){
        my @chomp=split(":", $item);                                                                                                                 
        $s_count{$chomp[0]} = $chomp[1];
      }
    }
  }
  open (BUNDLE, ">$readfile");                                 
  close BUNDLE;                      
  open (BUNDLE, ">>$readfile");
  logger("json_root: $json_root\n", 1);
  $critical_ids="";
  $warn_ids="";
  $ok="";
  $critical="";
  $warning="";
  $unknown="";
  foreach my $item( $decode) { 
    my $arrayref = $item->{$json_root};
    my $num   = scalar @$arrayref;
    my $state;
    my $id;
    my $name;
    my $version;
    my $symbolicName;
    logger("\tNumber of Bundles: $num\n", 1);
    $total_failures = $total_failures+$num;
    for (my $i=0; $i<$num; $i++){
      $id           = @$arrayref->[$i]->{'id'};
      $state        = @$arrayref->[$i]->{'state'};
      $name         = @$arrayref->[$i]->{'name'};
      $version      = @$arrayref->[$i]->{'version'};
      $symbolicName = @$arrayref->[$i]->{'symbolicName'};
      my $ignore = grep(/$id/i, @expected);
      $alarm_return = 0;
      #logger("state: $id $state $name $version $symbolicName\n",1);
      my $curl_b;
      if ($state =~/Resolved/){
        logger("State of $id is Resolved\n", 1);
        my $run_curl;
        $critical_ids = "$critical_ids"." "."$id";
        $critical = 1;
        if($ignore == 0){
          if($s_count{$id} < 3 && $eventhandler == 1){
            logger("Trying to start bundle: $id\n", 1);
            logger("Running: curl -u $user:$pass http://$instance:$port/system/console/bundles/$symbolicName -Faction=start > /dev/null 2>&1\n", 1);
            eval {
              local $SIG{ALRM} = sub {die "alarm\n"};
              alarm 10;
              $run_curl = `curl -s -u $user:$pass http://$instance:$port/system/console/bundles/$symbolicName -Faction=start 2>&1`;
              alarm 0;
            };
            if ($@) {
              die unless $@ eq "alarm\n";
              logger("TIMEOUT: curl -s -u $user:$pass http://$instance:$port/system/console/bundles/$symbolicName -Faction=start 2>&1\n",1);
              $alarm_return = 1;
            }else {
              logger("Curl command completed successfully\n",1);
              my @r_curl = split(":", $run_curl);
              $r_curl[2]=~s/\}//g;
              $curl_b = $r_curl[2];
              logger("Returned: $curl_b\n", 1);
              if ($curl_b == 32){
                $critical = 0;
              }else{
                $critical = 1;
              }
            }
            #my $run_curl = `curl -s -u $user:$pass http://$instance:$port/system/console/bundles/$symbolicName -Faction=start 2>&1`;
          }else{
            $curl_b = 1;
          }
          if ($curl_b != 0){
            my $s_num;
            if ($s_count{$id}){
              $s_num = $s_count{$id}+1;
            }elsif($s_count{$id} > 3){
              $s_num = 4;
            }else{
              $s_num = 1;
            }
            print BUNDLE "$id:$s_num\n" if ($eventhandler && $curl_b != 32);
          }
          $fixed_bundle_return = $fixed_bundle_return + $curl_b;
        }
      }elsif ($state =~/Installed/ || $state=~/Fragment/){
        logger("State $id is either installed or fragmented\n", 1);
        my $run_curl;
        if($state eq "Installed" && $ignore == 0){
          if($s_count{$id} < 3 && $eventhandler ==1){
            logger("Trying to start bundle: $id\n", 1);
            logger("Running: curl -u $user:$pass http://$instance:$port/system/console/bundles/$symbolicName -Faction=start > /dev/null 2>&1\n",1);
            eval {
              local $SIG{ALRM} = sub {die "alarm\n"};
              alarm 10;
              $run_curl = `curl -s -u $user:$pass http://$instance:$port/system/console/bundles/$symbolicName -Faction=start 2>&1`;
              alarm 0;
            };
            if ($@) {
              die unless $@ eq "alarm\n";
              logger("TIMEOUT: curl -s -u $user:$pass http://$instance:$port/system/console/bundles/$symbolicName -Faction=start 2>&1\n",1);
              $alarm_return = 1;
            }else {
              logger("Curl command completed successfully\n",1);
              my @r_curl = split(":", $run_curl);
              $r_curl[2]=~s/\}//g;
              $curl_b = $r_curl[2];
              logger("Returned: $curl_b\n", 1);
              if ($curl_b == 32){
                $critical = 0;
              }else{
                $critical = 1;
              }
            }
            #my $run_curl = `curl -s -u $user:$pass http://$instance:$port/system/console/bundles/$symbolicName -Faction=start 2>&1`;
          }else{
            $curl_b = 1;
            $critical = 1;
          }
          if ($curl_b != 0){
            my $s_num;
            if ($s_count{$id} < 4){
              $s_num = $s_count{$id}+1;
            }elsif($s_count{$id} > 3){
              $s_num = 4;
            }else{
              $s_num = 1;
            }
            print BUNDLE "$id:$s_num\n" if ($eventhandler && $curl_b != 32);
          }
          $fixed_bundle_return = $fixed_bundle_return + $curl_b;
        }
        if ($critical != 1 && $ignore != 0){
          $warn_ids = "$id"." "."$warn_ids";
          $warning = 1;
        }
      }elsif($state=~/Active/){
        if ($critical != 1 && $warning != 1){
          $ok = 1;
        }
      }else{
        logger("State of $id si unknown\n", 1);
        $unknown = 1;
      }
    }
    if($critical == 1){
      $string = "CRITICAL: Following id's are in Resolved state: $critical_ids";
      $exit_code = 1;
    }else{
      if($eventhandler){
        if ($fixed_bundle_return > 0){
          $fixed_bundle_return = 2;
        }
        do_output("", $exit_code);
      }else{
        if ($warning == 1){
          chop $warn_ids;
          my @split=split("\ ", $warn_ids);
          my $length=scalar(@split);
          $warn_ids=~s/\ /, /g;
          if ($length <= 7){
            $string="OK: Bundle ID's in installed/fragment state ->($warn_ids) $length";
            $exit_code=0;
          }else{
            $string="CRITICAL: Bundle ID's in installed/fragment state ->($warn_ids) $length";
            $exit_code=2;
          }
        }elsif($unknown == 1){
          $string="UNKNOWN: Bundle has status other than (installed|fragment|resolved|Active)";
          $exit_code = 3;
        }else{
          $string="OK: All bundles are started";  
          $exit_code=0;
        }
      }
    }
  }
  close BUNDLE;
  do_output($string, $exit_code);
}
sub do_output{
  my $string     = $_[0];
  my $exit_code  = $_[1];
  if (!$eventhandler){
    logger("$string\n", 0);
  }
  exit ($exit_code);
}
sub curl{
  my $base_url  = $_[0];
  my $user      = $_[1];
  my $pass      = $_[2];
  my $url="$base_url -u"." $user".":"."$pass";
  my $content = `curl -s $url`; 
  my $return = $?;
  logger("main curl -s $url\n", 1);
  logger("returned: $return\n", 1);
  if ($return != 0){
    logger("UNKNOWN - curl $base_url returned: $return\n",0);
    exit 3;
  }else{
    return $content;
  }
}

sub logger{
  my $data = $_[0];
  my $type = $_[1];
  if ($type == 0){
    print "$data";
  }elsif ($type == 1){
    print "$data" if ($debug);
  }else{
    print OUT "$data";
  }
}
close OUT;