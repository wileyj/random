#!/usr/bin/perl

use Net::LDAP;
use Time::Local;
use Getopt::Long;
use Fcntl qw(:flock);

GetOptions(
  "debug|d"      => \$DEBUG,
  "replace|r"    => \$REPLACE,
  "help|h"       => \$HELP

);
if ($HELP){
  &usage;
  exit 0;
}
$epochtime = int time / 86400;
$map_file = "/etc/mapped";
$location=`hostname | cut -d "." -f 2`;
chomp $location;

if ($location eq ""){
  print "Host Location Not Found\n" if ($DEBUG);
  exit;
}
if ($location ne "use1" && $location ne "usw1" && $location ne "usw2"){ 
  print "Bad Location: $location\n" if ($DEBUG);
  exit;
}
print "Using Location: $location\n" if ($DEBUG);

if ($location eq "use1"){
  our $shell        = "/export/jail/bin/rzsh";
  our $home         = "/export/jail/home/rzshuser";
  our $passwd       = "/etc/passwd";
  our $shadow       = "/etc/shadow";
  our $passwd2      = "/etc/passwd2";
  our $shadow2      = "/etc/shadow2";
  our $allowed_host = "shared-bastion-001.use1.local.com";
  our $ldap_server  = "platform-ldap-001.use1.local.com";
}
if ($location eq "usw1"){
  our $shell        = "/export/jail/bin/rzsh";
  our $home         = "/export/jail/home/rzshuser";
  our $passwd       = "/etc/passwd";
  our $shadow       = "/etc/shadow";
  our $passwd2      = "/etc/passwd2";
  our $shadow2      = "/etc/shadow2";
  our $allowed_host = "shared-bastion-001.usw1.local.com";
  our $ldap_server  = "platform-ldap-001.usw1.local.com";
}
if ($location eq "usw2"){
  our $shell        = "/export/jail/bin/rzsh";
  our $home         = "/export/jail/home/rzshuser";
  our $passwd       = "/etc/passwd";
  our $shadow       = "/etc/shadow";
  our $passwd2      = "/etc/passwd2";
  our $shadow2      = "/etc/shadow2";
  our $allowed_host = "shared-bastion-001.usw2.local.com";
  our $ldap_server  = "platform-ldap-001.usw2.local.com";
}
if (-f "$passwd2"){system("rm -f $passwd2");}
if (-f "$shadow2"){system("rm -f $shadow2");}

print "Allowed Host: $allowed_host\n" if ($DEBUG);
print "LDAP server: $ldap_server\n" if ($DEBUG);
print "temp passwd file: $passwd2\n" if ($DEBUG);
print "temp shadow file: $shadow2\n\n" if ($DEBUG);

my %currentpasswd= ();
my %currentshadow = ();
my %newpasswd = ();
my %newshadow = ();
my %mapped = ();
my %replace_pass = ();
my %reserved = ();
print "Using User Mapfile: $map_file\n" if ($DEBUG);
open (MAP, "$map_file");
@mapped=<MAP>;
close MAP;
foreach $map(@mapped){
  chomp $map;
  @getname = split(":", $map); 
  $mapped{$getname[0]} = "$getname[1]";
}
## retrieve info from ldap server
print "Retrieving Data from LDAP\n" if ($DEBUG);
$base = "ou=People,dc=local,dc=com";
$ldap = Net::LDAP->new ("$ldap_server") or die "$@";
$mesg = $ldap->bind( 'cn=System2005,ou=LDAPusers,dc=local,dc=com',
                        password => 'password'
                    );

#$result = $ldap->search (base => "$base",
#  filter => "uid=*",
#);
$result = $ldap->search (
  base => "$base",
  filter => ("host=*$allowed_host*"),
  timelimit => 60,
  attrs => ['host','uid','uidnumber','userpassword','gidnumber','gecos','employeetype','shadowlastchange']
);
$ldap->unbind;

# get all the ldap attrs, grep out what we want and assing vars.
# do a check  for the allowed_host, if user has host listed in 
# the list of hosts---they are allowed on this system
# and are included in the passwd files
my $href = $result->as_struct;
my @arrayOfDNs  = keys %$href;        # use DN hashes
$ldap_len = scalar(@arrayOfDNs);
if ($ldap_len < 10){
  print "Less than 10 Results returned from LDAP. Probably an error\n" if (DEBUG);
  print "Exiting...\n\n" if ($DEBUG);
  exit 1;
}
print "Parsing through $ldap_len records\n" if ($DEBUG);
foreach ( @arrayOfDNs ) {
  my $valref = $$href{$_};
  my @arrayOfAttrs = sort keys %$valref; #use Attr hashes
  my $attrName;        
  my $islocked;
  foreach $attrName (@arrayOfAttrs) {
    next if ( $attrName =~ /;binary$/ );
    my $attrVal =  @$valref{$attrName};
    if ($attrName eq "uid"){$uid = "@$attrVal";}
    if ($attrName eq "uidnumber"){$uidNumber = "@$attrVal";}
    if ($attrName eq "gidnumber"){$gidNumber = "@$attrVal";}
    if ($attrName eq "gecos"){$fullname = "@$attrVal";}
    if ($attrName eq "host"){$host = "@$attrVal";}
    if ($attrName eq "userpassword"){$password = "@$attrVal";$password =~ s/{crypt}//;}
    if ($attrName eq "employeetype"){$islocked = "@$attrVal";}
  }
  if ($host =~/$allowed_host/ && $islocked eq ""){
    if ($location ne "usw1"){ 
      if ($password=~/{CRYPT}/){
        print "\nFound Strange hash \"{CRYPT}\" in passwd for $uid\n" if ($DEBUG);
        print "Correcting passwd hash for $uid\n\n" if ($DEBUG);
        $password=~s/{CRYPT}//g;
      }
      $newpasswd{$uid} = "$uid".":x:"."$uidNumber".":"."$gidNumber".":"."$fullname".":"."$home:"."$shell";
      $newshadow{$uid} = "$uid".":"."$password".":"."$epochtime".":0:99999:7:::";
    }else{
      $newpasswd{$uid} = "$uid".":"."*:"."$uidNumber".":"."$gidNumber".":"."$fullname".":"."$home".":"."$shell";
      $newshadow{$uid} = "$uid".":"."$password".":"."$uidNumber".":"."$gidNumber"."::0:0:"."$fullname".":"."$home".":"."$shell";
    }
  }else{
    if ($islocked ne "" && $host =~/$allowed_host/){}
    if ($islocked eq "" && $host !~/$allowed_host/){}
    if ($islocked ne "" && $host !~/$allowed_host/){}
  }
  $islocked="";
}
$len=keys( %newpasswd );
$len2=keys( %newshadow);
print "Found $len allowed users of $ldap_len\n" if ($DEBUG);
if ($len < 1 || $len2 < 1){
  exit 1;
}


## read through passwd file, create hash
print "\nReading: $passwd\n" if ($DEBUG);
my %list = ();
open (PASSWD, "$passwd");
while(<PASSWD>){
  chomp $_;
  @parse=split(":", $_);
  $parse[1] =~ s/([\$\#\@\\])/\\$1/g;
  $parselen = scalar(@parse);
  $num = $parselen-1;
  if ($parse[$num] ne "$shell"){
## SAVE SYSTEM ACCOUNTS HERE
    if ($parse[3] < 500 || $parse[3] == 4294967294){
      #print "line: $_\n" if ($DEBUG);
      $reserved{$parse[0]} = $_;
    }
    $mapname = $mapped{$parse[0]};
    if ($mapname ne ""){
      $getmappedshadow = $newshadow{$mapname};
      @getpass = split(":", $getmappedshadow);
      $getmappedshadow=~s/$mapname/$parse[0]/g;
      $newshadow{$parse[0]} = "$getmappedshadow";
      $replace_pass{$parse[0]} = $getpass[1]; 
    }
    $list{$parse[0]} = 1;
    $newpasswd{$parse[0]} = "$_";
  }
}
$len3=keys( %newpasswd);
close PASSWD;
print "Parsed $len3 records in the passwd file\n" if ($DEBUG);
print "Closing Passwd file\n\n" if ($DEBUG);

## read through shadow file, create hash 
print "Reading: $shadow\n" if ($DEBUG);
open (SHADOW,"$shadow");
while (<SHADOW>){
  chomp $_;
  @parse=split(":", $_);
  if($list{$parse[0]} == 1){
    if ($replace_pass{$parse[0]} ne ""){
      $_=~s/$parse[1]/$replace_pass{$parse[0]}/g;
    }
    if ($reserved{$parse[0]} ne ""){
      $newshadow{$parse[0]} = "$_";
    }
  }
}
$len4=keys(%newshadow);
close SHADOW;
print "Parsed $len4 records in the shadow file\n" if ($DEBUG);
print "Closing Shadow file\n\n" if ($DEBUG);

## read through the hashes.
## if user already on system, replace info with ldap info
while ( my ($key, $value) = each(%newpasswd) ) {
  if ($currentpasswd{$key} ne ""){
    $currentpasswd{$key} = $value;
  }else{
    $currentpasswd{$key} = $value;
  }
}
print "Finished parsing and adding passwd entries\n" if ($DEBUG);
while (my ($key, $value) = each(%newshadow) ){
    if ($currentshadow{$key} ne ""){
      $currentshadow{$key} = $value;
    }else{
      $currentshadow{$key} = $value;
    }
  }
  print "Finished parsing and adding shadow entries\n" if ($DEBUG);

# read through the sorted hash, print to a temp file and then move it
open (PASSWD, ">>$passwd2");
print "Locking $passwd2 for writing\n" if ($DEBUG);
flock (PASSWD, LOCK_EX);
foreach $key (sort keys %currentpasswd){
  chomp $currentpasswd{$key};
  print PASSWD "$currentpasswd{$key}\n";
}
flock (PASSWD, LOCK_UN);
close PASSWD;
open (SHADOW, ">>$shadow2");
print "Locking $shadow2 for writing\n" if ($DEBUG);
flock (SHADOW, LOCK_EX);
foreach $key (sort keys %currentshadow){
    chomp $currentshadow{$key};
    print SHADOW "$currentshadow{$key}\n";
}
flock (SHADOW, LOCK_UN);
close SHADOW;

print "Finished Writing Temp passwd/shadow Files\n" if ($DEBUG);
if($REPLACE){
print "Moving $passwd2 --> $passwd\n" if($DEBUG); 
system ("mv $passwd2 $passwd");
print "Moving $shadow2 --> $shadow\n" if($DEBUG);
system ("mv $shadow2 $shadow");
print "Moved temp files into place\n" if ($DEBUG);
}else{
  print "new passwd file saved as: $passwd2\n" if ($DEBUG);
  print "new shadow file saved as: $shadow2\n" if ($DEBUG);
}
print "\nDONE\n\n" if ($DEBUG);
if ($DEBUG){
  while (my ($key2, $value) = each (%reserved) ){
 #   print "key: $reserved{$key2} :: value: $value\n";
  }
}
sub usage(){
print"
Usage: syncpasswd
Options:
        --DEBUG     (-d)
        --replace   (-r) Replace current passwd/shadow files
        --help      (-h) Displays this Message

";
exit 0;
}

