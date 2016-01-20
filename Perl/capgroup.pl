#!/usr/bin/perl

use strict ;

use Net::LDAP;
use Fcntl qw(:flock);

my $capgroup = shift ;
my $mask = shift ;

#my $ldap_server="ldaps://ldap.811.mtvi.com:636";
my $ldap_server="ldap://ldap.811.mtvi.com:389";
my @hostlist ;

## retrieve info from ldap server
my $base = "ou=Hosts,dc=mtvi,dc=com";
my $ldap = Net::LDAP->new ("$ldap_server") or die "$@";
my $mesg = $ldap->bind( 'cn=System2005,ou=LDAPusers,dc=mtvi,dc=com',
                        password => 'lN/R1yW3'
                    );

my $result = $ldap->search (base => "$base", filter => "cn=$mask");

###########  list of attributes  ###########
############################################
#	cn
#	ipHostNumber
#	l
#	opjectClass


my @hostqueryref = $result->sorted ;
foreach my $hostref (@hostqueryref)
{
  my $hostnameref = $hostref->get_value( 'cn', asref => 1 ) ;
  #print @$hostnameref[0] . "\n"
  push( @hostlist, @$hostnameref[0] ) ;
}

print "role :$capgroup" ;

foreach my $host ( @hostlist )
{
  print ", \"$host\"" ;
}

print "\n" ;
