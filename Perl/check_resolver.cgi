#!/usr/bin/perl

use CGI qw(:standard escapeHTML);

my $host = param('host');
my $instance = param('instance');
my $service = param('service');

print header(), start_html("Nagios Check Resolver");

open (HOSTGROUPS,"/opt/nagios/etc-$instance/hostgroups.cfg");
while (<HOSTGROUPS>) {
  if (/hostgroup_name\s+(\S+)$/) {
    $hostgroup = $1;
  } elsif ((/members\s+\S+$/) && (/$host/)) {
    print p("Found $host in hostgroup $hostgroup");
    push (@hostgroups,$hostgroup);
  }
}
close (HOSTGROUPS);

open (HOSTS,"/opt/nagios/etc-$instance/hosts.cfg");
while (<HOSTS>) {
  if (/host_name\s+(\S+)$/) {
    if ($1 eq $host) {
      $found_host = 1;
    } else {
      $found_host = 0;
    }
  }
  if ((/address\s+(\S+)$/) && ($found_host == 1)) {
    print p("Found $host in hosts.cfg, address=$1");
    $address = $1;
  }
}
close (HOSTS);

open (SERVICES,"/opt/nagios/etc-$instance/services.cfg");
while (<SERVICES>) {
#  if (/service_description\s+(\S+)$/) {
#    $t_serv_desc = $1;
#  }
#  if (/host_name\s+(\S+)$/) {
#    $t_hostname = $1;
#    #if (($t_hostname =~ /,$host$/) || ($t_hostname =~ /,$host,/) || ($t_hostname =~ /^$host,/) || ($t_hostname =~ /^$host$/)) {
#    #  $real_hostname = $t_hostname;
#    #  print p("t_hostname $t_hostname");
#    #  $service_found = 1;
#    #}
#  }
#  if (/check_command\s+(\S+)$/) {
#    $t_service_cmd = $1;
#  }
#  if (/}/) {
#    if (($t_serv_desc eq $service) && (($t_hostname =~ /,$host$/) || ($t_hostname =~ /,$host,/) || ($t_hostname =~ /^$host,/) || ($t_hostname =~ /^$host$/))) {
#      print p("Found $service on host $host in services.cfg, check_command=$t_service_cmd");
#      $service_cmd = $t_service_cmd;
#    }
#    #$real_hostname = "";
#  }
  if (/service_description\s+(\S.*)$/) {
    $t_serv_desc = $1;
  }
  if (/host_name\s+(\S.*)$/) {
    $t_hostname = $1;
  }
  if (/hostgroup_name\s+(\S.*)$/) {
    $t_hostgroup = $1;
  }
  if (/check_command\s+(\S.*)$/) {
    $t_service_cmd = $1;
  }
  if (/}/) {
    if (defined($t_hostname)) {
      @t_hosts = split(/,/,$t_hostname);
    } elsif (defined($t_hostgroup)) {
      @t_hosts = split(/,/,$t_hostgroup);
    }
    foreach $t_host (@t_hosts) {
      $keystr = $t_host."-".$t_serv_desc;
      $service_hash{$keystr}=$t_service_cmd;
    }
    undef($t_serv_desc);
    undef($t_hostname);
    undef($t_hostgroup);
    undef($t_service_cmd);
  }
}
close (SERVICES);

$host_found = 0;
$keystr = $host."-".$service;
if (defined($service_hash{$keystr})) {
  print "Found $keystr :: $service_hash{$keystr}<BR>\n";
  $service_cmd = $service_hash{$keystr};
  $host_found = 1;
} else {
  foreach $hostgroup (@hostgroups) {
    $keystr = $hostgroup."-".$service;
    if (defined($service_hash{$keystr})) {
      print "Found $keystr :: $service_hash{$keystr}<BR>\n";
      $service_cmd = $service_hash{$keystr};
      $host_found = 1;
    }
  }
}

if (!$host_found) {
  print "No command found for $service under $host or its hostgroups\n";
}

@command_parts = split(/!/,$service_cmd);

open (COMMANDS,"/opt/nagios/etc-shared/commands.cfg");
while (<COMMANDS>) {
  if ((/command_name\s+(\S*)/) && ($1 eq $command_parts[0])) {
    print p("Command $1 found in commands.cfg");
    $command_found=1;
  }
  if ((/command_line\s+(\S.*)$/) && ($command_found > 0)) {
    $command_string = $1;
  }
  if (/}/) {
    if ($command_found > 0) {
      $command_string =~ s#\$USER1\$#/opt/nagios/libexec#g;
      $command_string =~ s#\$HOSTADDRESS\$#$host#g;
      $curr_arg = 1;
      while ($curr_arg <= $#command_parts) {
        $command_string =~ s#\$ARG$curr_arg\$#$command_parts[$curr_arg]#g;
        $curr_arg++;
      }
      print p("Final resolved command:",b("$command_string"));
      print "Output of command:\n";
      print "<B>";
      $retcode = system("$command_string");
      print "</B><BR>\n";
      print "Return code: <B>$retcode</B>\n";
    }
    $command_found = 0;
  }
}
close (COMMANDS);

print end_html();
