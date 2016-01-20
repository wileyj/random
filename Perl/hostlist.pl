#!/usr/bin/perl
use strict ;
my $doLookup;
my $hideip;
if ($ARGV[0] eq ""){
  print "usage:\n";
  print "./hostlist.pl *.use1*\n";
  print "optionally, add \"-y\" to get the ip\n";
  exit 0;
}
if ($ARGV[1] ne ""){
  $doLookup=1;
}if ($ARGV[2] eq "-n"){
  $hideip=1;
}
use Net::LDAP;
use Fcntl qw(:flock);

my $mask = shift ;
my $ping;
my $ldap_server="ldap://platform-ldap-001.use1.local.com:389";
my @hostlist ;

## retrieve info from ldap server
my $base = "ou=Hosts,dc=local,dc=com";
my $ldap = Net::LDAP->new ("$ldap_server") or die "$@";
my $mesg = $ldap->bind( 'cn=System2005,ou=LDAPusers,dc=local,dc=com',
                        password => 'password'
                    );

my $result = $ldap->search (base => "$base", filter => "cn=$mask");

###########  list of attributes  ###########
############################################
#	cn
#	ipHostNumber
#	l
#	opjectClass


my @hostqueryref = $result->sorted ;
my $len=scalar(@hostqueryref);
foreach my $hostref (@hostqueryref)
{
  my $hostnameref = $hostref->get_value( 'cn', asref => 1 ) ;
  push( @hostlist, @$hostnameref[0] ) ;
}
foreach my $host ( @hostlist )
{
  my $nslookup = `nslookup $host | tail -2 | cut -f2 -d ":"`;
  chomp $nslookup;
  chomp $nslookup;
  if ($doLookup ==1){
    $ping=`ping -c 1 $nslookup -t 10 | grep "transmitted" | cut -f4 -d" "`;
    chomp $ping;
  }
  if ($doLookup == 1 && $ping ==1){
    if ($hideip !=1){
      print "$host :: $nslookup\n";
    }else{
      print "$host\n";
    }
  }elsif($doLookup ==1 && $ping !=1){
    if ($hideip !=1){
      print "$host :: $nslookup :: NOT PINGABLE\n";
    }else{
      print "$host\n";
    }
  }else{
    print "$host\n";
  }
}
-ba
