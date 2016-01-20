#!/usr/bin/perl 

use Net::LDAP;

my $ldap_server="ldap://platform-ldap-001.use1.local.com:389";
my $user=$ARGV[0];
chomp $user;

print "ldap_server: $ldap_server\n";
$internalbase = "ou=People,dc=local,dc=com";
$externalbase = "ou=ExternalPeople,dc=local,dc=com";
$systembase = "ou=System,dc=local,dc=com";
$groupbase = "ou=Group,dc=local,dc=com";

$ldap = Net::LDAP->new ("$ldap_server") or die "$@";
$mesg = $ldap->bind( 'cn=System2005,ou=LDAPusers,dc=local,dc=com',
                        password => 'password'
                    );

$result = $ldap->search (
  base => "$internalbase",
  filter => ("uid=$user"),
  #filter => ("cn=admins"),
  timelimit => 60,
  #attrs => ['uid', 'cn', 'gecos','employeetype', 'recordcreatedtime', 'ftpQuota', 'ftpAccess', 'mail', 'recordcreatedtime']
  #attrs => ['uid', 'cn', 'mail', 'employeetype']
attrs => [ 'uid', 'uidnumber', 'gidnumber', 'mail', 'gecos', 'givenname', 'sn', 'cn', 'description', 'homedirectory', 'loginshell', 'ftpaccess', 'ftpquota',  'ou', 'recordcreatedtime', 'recordcreator', 'recordupdatedtime', 'recordupdater', 'employeetype' ]

);
$ldap->unbind;



my $href = $result->as_struct;
my @arrayOfDNs  = keys %$href;        # use DN hashes
foreach ( @arrayOfDNs ) {
  my $valref = $$href{$_};
  my @arrayOfAttrs = sort keys %$valref; #use Attr hashes
  my $attrName;        
  my $islocked;
  foreach $attrName (@arrayOfAttrs) {
    my $attrVal =  @$valref{$attrName};
    print "attrname: $attrName :: @$attrVal\n";
  }
print "\n";
}
#}
