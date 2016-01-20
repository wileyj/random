#!/usr/bin/perl

use strict;
use warnings;
use IO::Socket::INET;
use POSIX;
our $failed;
our $host;
our $port;
our @lines;

if (-f "socket-list"){
  (my $dev,my $ino,my $mode,my $nlink,my $uid,my $gid,my $rdev,my $size,my $atime,my $mtime,my $ctime,my $blksize,my $blocks) = stat("socket-list");
  if ($size > 0){
    open (FILE, "socket-list");
    @lines=<FILE>;
    close FILE;
  }else{
    &ask;
  }
}else{
  &ask;
}
foreach my $line(@lines){
  chomp $line;
  ($host, $port)=split(":", $line);
  $failed=0;
  my $sock= IO::Socket::INET->new(
    PeerAddr => $host,
    PeerPort => $port,
    Proto    => 'tcp',
    Timeout  => 1
  ) or $failed=1;
  if ($failed == 0){
    print "$host $port OPEN\n";
  }else{
    print "$host $port CLOSED\n";
  }
}
sub ask(){
  print "host/ip: ";
  $host=<STDIN>;
  chomp $host;
  print "port: ";
  $port=<STDIN>;
  chomp $port;
  my $new="$host".":"."$port";
  push (@lines, $new);
}

