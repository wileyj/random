#!/usr/bin/perl

if ($ARGV[0] eq "-d"){
  $debug = 1;
}
$hostname = `hostname`;
$hostname_s = `hostname | cut -f1 -d "."`;
open (FILE, ">/etc/sudoers.d/01-admins");
print FILE "%admins  ALL=(ALL) ALL\n";
close FILE;

open (FILE, ">/etc/sysconfig/iptables.restore");
close FILE;
open (FILE, ">>/etc/sysconfig/iptables.restore");
print FILE"
*filter
:INPUT ACCEPT [1813920299:1635867100050]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [956449416:439904445805]
-A INPUT -s 10.0.0.0/255.0.0.0 -p icmp -m icmp --icmp-type 8 -j ACCEPT 
-A INPUT -p icmp -m icmp --icmp-type 8 -j DROP 
COMMIT
";
close FILE;
system("iptables-restore /etc/sysconfig/iptables.restore");

if (! -d "/opt/scripts"){
  system("mkdir -p /opt/scripts");
}
@disabled_services=(
"acpid",
"atd",
"auditd",
"blk-availability",
"ip6tables",
"irqbalance",
"lvm2-monitor",
"mdmonitor",
"messagebus",
"netconsole",
"netfs",
"psacct",
"rdisc",
"saslauthd",
);
foreach $item(@disabled_services){
  system("chkconfig $item off > /dev/null 2>&1");
}
if (!-d "/etc/ssh/authorized_keys/"){
  print "Creating keydir: /etc/ssh/authorized_keys\n";
  system("mkdir -p /etc/ssh/authorized_keys/");
}
open (FILE, ">/opt/scripts/syncpass-chroot");
close FILE;
open (FILE, ">>/opt/scripts/syncpass-chroot");
print FILE"#!/usr/bin/perl
open (FILE, \"/etc/passwd\");
\@passwd=<FILE>;
close FILE;

open (FILE, \"/etc/shadow\");
\@shadow=<FILE>;
close FILE;

open (FILE, \"/etc/group\");
\@groups=<FILE>;
close FILE;

my \%p;
my \%s;
open (OUT, \">/export/jail/etc/passwd\");
close OUT;
open (OUT, \">/export/jail/etc/shadow\");
close OUT;
open (OUT, \">/export/jail/etc/group\");
close OUT;

open (GROUP, \">>/export/jail/etc/group\");
foreach \$group(\@groups){
  chomp \$group;
  \@split=split(\":\", \$group);
  if (\$split[2] == 501){
    print GROUP \"\$group\\n\";
  }
}
close GROUP;

foreach \$line(\@passwd){
  chomp \$line;
  my (\$user,\$pass,\$uid,\$gid,\$name,\$home,\$shell) = split(\":\", \$line);
  if (\$gid >= 501){

    \$p{\$user}{'user'} = \$user;
    \$p{\$user}{'pass'} = \"\";
    \$p{\$user}{'uid'} = \$uid;
    \$p{\$user}{'gid'} = \$gid;
    \$p{\$user}{'name'} = \$name;
    \$p{\$user}{'home'} = \$home;
    \$p{\$user}{'shell'} = \$shell;
    \$p{\$user}{'line'} =  \$p{\$user}{'user'}.\":x:\".\$p{\$user}{'uid'}.\":501:\".\$p{\$user}{'name'}.\":/home/rzshuser:/bin/rzsh\";

    #\$p{\$user}{'line'} =  \$p{\$user}{'user'}.\":x:\".\$p{\$user}{'uid'}.\":501:\".\$p{\$user}{'name'}.\":\".\$p{\$user}{'home'}.\":/bin/rzsh\";
    # if (!-f \"/export/jail/home/\$p{\$user}{'user'}\"){
    #   system(\"cp -a /etc/skel-jail /export/jail/home/\$p{\$user}{'user'}\");
    #   system(\"chown -R \$p{\$user}{'user'}:jailed  /export/jail/home/\$p{\$user}{'user'}\");
    # }
    open (FILE, \">/etc/ssh/authorized_keys/\$p{\$user}{'user'}\");
    print FILE \"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCNcmtFxi49yvp1WB9LYME87mGzNvtFybcfpHvjoV46UbzQE26VuNnobq2B2tdFKElbzWKif4Ry9HQWD2eutrq2npvvr\/Mfrb0LO\/eLKI0Z3WDArzYqImjIhDFM\+JdsMFjvLGgmYkgvFJoqukrewGnU385pzVfHn7uqUy2aAnBycPzWuif2UQnHd7J8DUvMTvOQVfcaj7Nx1irqrMIym5ss58nHS6JLvMNGe\/9IO\/oxoBqT69PWZRmL8Aj1fbMJsD6NO489rLq7MHTEvUWACPPIustJnl1m2HPlB5C3prse55s\/gnRlMODRHaVa7hTicLfjB8j5lCECmBgO9cGmvGwX RHM-Master\\n\";
    close FILE;
  }
}

foreach \$line(\@shadow){
  chomp \$line;
  my (\$user,\$pass,\$lastchange,\$min,\$max,\$warn,\$inactive,\$expire) = split(\":\", \$line);
  if ( \$p{\$user}{'gid'} >= 501 ){
    \$s{\$user}{'line'} =  \$p{\$user}{'user'}.\":\".\$pass.\":\".\$lastchange.\":\".\$min.\":\".\$max.\":\".\$warn.\":\".\$inactive.\":\".\$expire.\":\";
  }
}
open (PASSWD, \">>/export/jail/etc/passwd\");
open (SHADOW, \">>/export/jail/etc/shadow\");
foreach \$key (sort keys \%p){
    chomp \$p{\$key}{'line'};
    if (\$p{\$key}{'line'}){
      print PASSWD \"\$p{\$key}{'line'}\\n\";
      print SHADOW \"\$s{\$key}{'line'}\\n\";
    }
}
close PASSWD;
close SHADOW;

";
close FILE;
system("grep local6  /etc/bashrc > 2&>1 > /dev/null");
$return=$?;
if ($return != 0){
  open (FILE, ">>/etc/bashrc");
  print FILE "export PROMPT_COMMAND='RETRN_VAL=$?;logger -p local6.debug \"\$(whoami) [\$\$]: \$(history 1 | sed \"s/^[ ]*[0-9]+[ ]*//\" ) [\$RETRN_VAL]\"'
";
  close FILE;
}
if (!-f "/etc/rsyslog.d/bash.conf"){
  open (FILE, ">>/etc/rsyslog.d/bash.conf");
  print FILE "local6.debug    /var/log/commands.log";
  close FILE;
  system("/etc/init.d/rsyslog restart");
}
system("chmod 755 /opt/scripts/syncpass-chroot");
open (FILE, ">/etc/cron.d/syncass-chroot");
close FILE;
open (FILE, ">>/etc/cron.d/syncass-chroot");
print FILE "*/2 * * * * root /usr/bin/perl /opt/scripts/syncpass-chroot\n";
close FILE;

open (FILE, ">/etc/ssh/sshd_config");
close FILE;
open (FILE, ">>/etc/ssh/sshd_config");
print FILE"
Port 22
Port 2243
#ListenAddress public
#ListenAddress private

Protocol 2
PermitRootLogin yes 
StrictModes yes
AllowTcpForwarding yes
GatewayPorts yes
TCPKeepAlive yes
UsePam yes
ClientAliveInterval 300
ClientAliveCountMax 0
PermitEmptyPasswords no
PasswordAuthentication yes
PubKeyAuthentication yes
DSAAuthentication no
IgnoreRhosts yes
LogLevel INFO
X11Forwarding no
AllowTcpForwarding yes
UsePrivilegeSeparation yes
AllowAgentForwarding yes
MaxSessions 20
LoginGraceTime 30
Ciphers 3des-cbc,aes256-ctr,aes192-ctr,aes128-ctr,arcfour256
UseDNS no
AuthorizedKeysFile  /etc/ssh/authorized_keys/%u
#Banner /etc/motd
#Subsystem   sftp    /usr/libexec/openssh/sftp-server

# Jailed
Match group jailed
ChrootDirectory /export/jail/
AllowAgentForwarding yes
MaxSessions 20
AllowTcpForwarding yes

# end Match
Match


";
close FILE;

system ("/etc/init.d/sshd restart");

system("getent group jailed");
if ($? != 0){
  system("groupadd -g 501 jailed");
}
system("getent group admins");
if ($? != 0){
  system("groupadd -g 105 admins");
}


open (FILE, ">/etc/pam.d/sshd");
close FILE;
open (FILE, ">>/etc/pam.d/sshd");
print FILE "#%PAM-1.0
auth     required pam_sepermit.so
auth       include      password-auth
account    required     pam_nologin.so
account    include      password-auth
password   include      password-auth
# pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
# pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open env_params
session    optional     pam_keyinit.so force revoke
session    include      password-auth
session     required      pam_mkhomedir.so umask=0022 skel=/etc/skel-jail/
session required pam_chroot.so";
close FILE;


open (FILE, ">>/etc/resolv.conf");
print FILE "search local.com";
close FILE;

open (FILE, ">/etc/hosts");
close FILE;

open (FILE, ">>/etc/hosts");
print FILE "
127.0.0.1       localhost localhost.localdomain localhost4 localhost4.localdomain4
::1             localhost localhost.localdomain localhost6 localhost6.localdomain6
10.2.254.7      shared-bastion-001 shared-bastion-001.live.hcaws.net
54.164.213.85   bh.live.hcaws.net
54.164.70.53    yumrepo.hcaws.net yumrepo";
close FILE;

open (FILE, ">/etc/yum.repos.d/rhm.repo");
close FILE;
open (FILE, ">>/etc/yum.repos.d/rhm.repo");
print FILE "
[rhm-x86_64]
name=rhm - x86_64
baseurl=http://yumrepo/rhm/x86_64
gpgcheck=0
priority=1

[rhm-noarch]
name=rhm - noarch
baseurl=http://yumrepo/rhm/noarch
gpgcheck=0
priority=1

[centos-x86_64]
name=centos - x86_64
baseurl=http://yumrepo/centos/6.5/x86_64
gpgcheck=0
priority=1

[centos-noarch]
name=centos - noarch
baseurl=http://yumrepo/centos/6.5/noarch
gpgcheck=0
priority=1
";
close FILE;

system ("yum clean all && yum install -y sensu-client zsh-chroot denyhosts telnet");

open (FILE, ">/etc/ntp.conf");
close FILE;

open (FILE, ">>/etc/ntp.conf");
print FILE "driftfile /var/lib/ntp/drift
server 0.amazon.pool.ntp.org iburst
server 1.amazon.pool.ntp.org iburst
server 2.amazon.pool.ntp.org iburst
server 3.amazon.pool.ntp.org iburst";
close FILE;

open (FILE, ">/opt/denyhosts/etc/denyhosts.cfg");
close FILE;
open (FILE, ">>/opt/denyhosts/etc/denyhosts.cfg");
print FILE "SECURE_LOG = /var/log/messages
HOSTS_DENY = /etc/hosts.deny
PURGE_DENY = 
BLOCK_SERVICE = ALL
DENY_THRESHOLD_INVALID = 3
DENY_THRESHOLD_VALID = 5 
DENY_THRESHOLD_ROOT = 3 
DENY_THRESHOLD_RESTRICTED = 3
WORK_DIR = /opt/denyhosts/data
SUSPICIOUS_LOGIN_REPORT_ALLOWED_HOSTS=YES
HOSTNAME_LOOKUP=YES
LOCK_FILE = /var/lock/subsys/denyhosts
ADMIN_EMAIL = mail@rhm
SMTP_HOST = x.x.x.x

SMTP_PORT = 25
SMTP_FROM = DenyHosts - shared-bastion-001.live.hcaws.net
SMTP_SUBJECT = shared-bastion-001.live.hcaws.net DenyHosts Report
SYSLOG_REPORT=YES
AGE_RESET_VALID=2d
AGE_RESET_ROOT=
AGE_RESET_RESTRICTED=
AGE_RESET_INVALID=
RESET_ON_SUCCESS = yes
DAEMON_LOG = /var/log/denyhosts
DAEMON_SLEEP = 30s
DAEMON_PURGE = 1h";
close FILE;

open (FILE, ">/etc/motd");
close FILE;

open (FILE, ">>/etc/motd");
print FILE "This system is made available to authorized Employees only.
Unauthorized access, attempts to defeat or circumvent security features,
to use the system for other than intended purposes, to deny service to
authorized users, or otherwise to interfere with the system or its operation
is strictly prohibited. Evidence of such acts will be disclosed to law
enforcement authorities and may result in criminal prosecution.
If you are not an authorized employee please logout immediately.

";
close FILE;


print "Creating Jailed root init\n" if ($debug);
if (! -d "/export/jail/lib64"){
  system("mkdir -p /export/jail/lib64 > /dev/null 2>&1");
}
if (! -d "/export/jail/usr/share/terminfo"){
  system("mkdir -p /export/jail/usr/share/terminfo > /dev/null 2>&1");
}
if (! -d "/export/jail/usr/lib64"){
  system("mkdir -p /export/jail/usr/lib64 > /dev/null 2>&1");
}
if (! -d "/export/jail/etc"){
   system("mkdir -p /export/jail/etc > /dev/null 2>&1");
}
system("cp -a /lib64/libnss* /export/jail/lib64/ > /dev/null 2>&1");
system("cp -a /usr/lib64/libnss* /export/jail/usr/lib64/ > /dev/null 2>&1");
system("cp -a /etc/nsswitch.conf /export/jail/etc/nsswitch.conf > /dev/null 2>&1");
system("cp -a /etc/hosts /export/jail/etc/hosts > /dev/null 2>&1");
system("cp -a /etc/resolv.conf /export/jail/etc/resolv.conf > /dev/null 2>&1");
system("cp -a /etc/system-release /export/jail/etc/system-release > /dev/null 2>&1");
system("cp -a /etc/security /export/jail/etc/security > /dev/null 2>&1");
system("cp -a /usr/share/terminfo/x /export/jail/usr/share/terminfo/ > /dev/null 2>&1");

open (FILE, ">/export/jail/etc/zshenv");
close FILE;
open (FILE, ">>/export/jail/etc/zshenv");
print FILE '#
# /etc/zshenv is sourced on all invocations of the
# shell, unless the -f option is set.  It should
# contain commands to set the command search path,
# plus other important environment variables.
# .zshenv should not contain commands that produce
# output or assume the shell is attached to a tty.
#

export PATH=/usr/bin:/bin
alias bindkey=""
alias compcall=""
alias compctl=""
alias compsys=""
alias source=""
alias vared=""
alias zle=""
alias bg=""

disable compgroups
disable compquote
disable comptags
disable comptry
disable compvalues
disable pwd
disable alias
disable autoload
disable break
disable builtin
disable command
disable comparguments
disable compcall
disable compctl
disable compdescribe
disable continue
disable declare
disable dirs
disable disown
disable echo
disable echotc
disable echoti
disable emulate
disable enable
disable eval
disable exec
disable export
disable false
disable float
disable functions
disable getln
disable getopts
disable hash
disable integer
disable let
disable limit 
disable local 
disable log 
disable noglob 
disable popd 
disable print 
disable pushd 
disable pushln
disable read 
disable readonly 
disable rehash 
disable sched 
disable set 
disable setopt 
disable shift 
disable source 
disable suspend 
disable test 
disable times 
disable trap 
disable true 
disable ttyctl 
disable type 
disable typeset 
disable ulimit 
disable umask 
disable unalias 
disable unfunction 
disable unhash 
disable unlimit 
disable unset 
disable unsetopt 
disable vared 
disable whence 
disable where 
disable which 
disable zcompile 
disable zformat 
disable zle 
disable zmodload 
disable zparseopts 
disable zregexparse 
disable zstyle';
close FILE;

print "Creating rzshuser homedir\n" if($debug);
if (! -d "/export/jail/home/rzshuser/.ssh"){
  system("mkdir -p /export/jail/home/rzshuser/.ssh > /dev/null 2>&1");
}
if (! -d "/export/jail/dev"){
  system("mkdir -p /export/jail/dev > /dev/null 2>&1");
}
if (! -c "/export/jail/dev/null"){
  system("mknod /export/jail/dev/null c 1 3 > /dev/null 2>&1");
  system("chmod 666 /export/jail/dev/null > /dev/null 2>&1");
}
if (!-c "/export/jail/dev/random"){
  system("mknod /export/jail/dev/random c 1 8 > /dev/null 2>&1");
  system("chmod 666 /export/jail/dev/random > /dev/null 2>&1");
}
if (!-c "/export/jail/dev/tty"){
  system("mknod /export/jail/dev/tty c 1 8 > /dev/null 2>&1");
  system("chmod 666 /export/jail/dev/tty > /dev/null 2>&1");
}
if (!-c "/export/jail/dev/urandom"){
  system("mknod /export/jail/dev/urandom c 1 9 > /dev/null 2>&1");
  system("chmod 666 /export/jail/dev/urandom > /dev/null 2>&1");
}

print "Linking /dev/null to rzshuser know_hosts files\n" if($debug);
if (!-l "/export/jail/home/rzshuser/.ssh/known_hosts"){
  system("ln -s /export/jail/dev/null /export/jail/home/rzshuser/.ssh/known_hosts > /dev/null 2>&1");
}
if (!-l "/export/jail/home/rzshuser/.ssh/known_hosts2"){
  system("ln -s /export/jail/dev/null /export/jail/home/rzshuser/.ssh/known_hosts2 > /dev/null 2>&1");
}

system("echo > /etc/zprofile");
system("echo > /etc/zlogout");
system("echo > /etc/zshrc");
system("echo > /etc/profile.d/lang.sh");
system("echo > /etc/profile");

%list=(
  '/usr/bin/strace'               => 'strace.x86_64',
  '/usr/bin/host'                 => 'bind-utils.x86_64',
  '/bin/ping'                     => 'iputils.x86_64',
  '/bin/rzsh'                     => 'zsh-chroot.x86_64',
  '/bin/traceroute'               => 'traceroute.x86_64',
  '/usr/bin/dig'                  => 'bind-utils.x86_64', 
  '/usr/bin/nslookup'             => 'bind-utils.x86_64', 
  '/usr/bin/ssh'                  => 'openssh-clients.x86_64',
  '/usr/bin/ssh-add'              => 'openssh-clients.x86_64',
  '/usr/bin/ssh-agent'            => 'openssh-clients.x86_64',
  '/usr/bin/telnet'               => 'telnet.x86_64',
);
while (my ($key, $value) = each (%list) ){
  if ( !-f $key){
    yuminstall($value);
    if ($? == 0){ 
      runldd($key);
    }
  }else{
    runldd($key);
  }
  if ($? == 0){
    copylibs($get_ldd, $key);
  }
}

if (! -d "/export/jail/dev/pts"){
  system("mkdir -p /export/jail/dev/pts");
  system("mount --bind /dev /export/jail/dev");
  system("mount -t devpts -o gid=5,mode=620 devpts /export/jail/dev/pts");
}

if (! -d "/export/jail/proc"){
  system("mkdir -p /export/jail/proc");
  system("mount -t proc /proc /export/jail/proc/");
}

if (! -d "/export/jail/sys"){
  system("mkdir -p /export/jail/sys");
  system("mount --bind /sys /export/jail/sys");
}
system("grep chroot /etc/fstab > /dev/null 2>&1");
if ($? != 0){
open (FILE, ">>/etc/fstab");
print FILE"
# chroot
proc  /export/jail/proc        proc    none                0 0
sysfs /export/jail/sys         sysfs   none                0 0
devpts  /export/jail/dev/pts     devpts  rw,gid=5,mode=620   0 0
/dev  /export/jail/dev  defaults  rw,bind   0 0
";
close FILE;
}
system("chmod u+s /export/jail/bin/ping");

exit 0;
sub yuminstall{
  $package = $_[0];
  print "Installing package $package\n" if($debug);
  system("yum install -y $package");
  return $?;   
}
sub runldd{
  $binary = $_[0];
  $get_ldd = `/usr/bin/ldd $binary `;
  return $?;
}
sub copylibs{
  $ldd = $_[0];
  $bin = $_[1];
  @split = split("\n", $ldd);
  $count=0;
  foreach $line(@split){
    $islink=0;
    print "Copying Library: $line\n";
    if ($line!~/linux-vdso/){
      chomp $line;
      @split2 = split(" ", $line);
      $firstchar = substr($split2[0],0,1);
      if ($firstchar eq "/"){
        $lib = $split2[0];
      }else{
        $lib = $split2[2];
      }
      if (-l $lib){
        $islink=1;
        $link = readlink($lib);
      }
      @jail_l = split('', $lib);
      $len_l=scalar(@jail_l);
      $loc_l = 0;
      for ($i=0; $i<$len_l; $i++){
        if ($jail_l[$i] eq "/"){
          $loc_l = $i;
        }
      }
      $base_l = substr($lib,0,$loc_l);
      $makedir_l = "/export/jail"."$base_l";
      if($islink == 1){
        $link_loc="$base_l"."/"."$link";
        $link_jail_loc="/export/jail"."$base_l"."/"."$link";
        if (!-f $link_jail_loc){
          print "***Copying link source: $link_loc $link_jail_loc\n" if($debug);
          system("cp -a $link_loc $link_jail_loc");
        }
      } 
      $lib_jail ="/export/jail"."$lib";
      if (!-d $makedir_l){
        print "Creating Dir: $makedir_l\n" if($debug);
        system("mkdir -p $makedir_l"); 
      }
      if(!-f $lib_jail){
        print "***Copying lib $lib to $lib_jail\n" if($debug);
        system("cp -a $lib  $lib_jail");
      }
    }
  }
  @jail_b = split('', $bin);
  $len_b=scalar(@jail_b);
  $loc_b = 0;
  for ($j=0; $j<$len_b; $j++){
    if ($jail_b[$j] eq "/"){
      $loc_b = $j;
    }
  }
  $base_b = substr($bin,0,$loc_b);
  $makedir_b = "/export/jail"."$base_b";
  $bin_jail = "/export/jail"."$bin";
  if(!-d $makedir_b){
    print "Creating dir: $makedir_b\n" if($debug);
    system("mkdir -p $makedir_b");
  }
  if (!-f  $bin_jail){
    print "***Copying binary $bin to $bin_jail\n" if($debug);
    system("cp -a $bin $bin_jail");
  }
}
$get_suid=`find /export/jail ! -path "*/proc*" -perm -4000 -type f`;
@suid_s = split("\n", $get_suid);
foreach $suid_file(@suid_s){
  chomp $suid_file;
  if ($file!~/ping/){
    print "Removing suid from $suid_file\n" if($debug);
    system("chmod u-s $suid_file");
  }
}