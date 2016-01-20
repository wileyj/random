#!/usr/bin/perl

use strict;
use POSIX;
use Getopt::Long;
my $debug;
my $help;
my $lv_name;
my $lv_name_full;
my $vg_name;
my $lv_size ="150G";
my $option;
my $lv_instance_name;
my $lv_binlogs_name;
my $lvcreate_instance_rc;
my $lvcreate_binlogs_rc;
my $mkfs_instance_rc;
my $mkdir_instance_rc;
my $mkdir_db_rc;
my $mkdir_binlog_rc;
my $mkdir_binlog;
my $mkdir_binlog_relay_rc;
my $mkdir_binlog_binlog_rc;
my $ln_relay;
my $ln_binlog;
my $mount_instance_rc;
my $mount_binlogs_rc;
my $chown_instance_rc;
my $chown_binlogs_rc;

GetOptions ('debug' => \$debug, 'help' => \$help, 'lv=s' => \$lv_name, 'vg=s' => \$vg_name, 'size=s' => \$lv_size, 'option=s' => \$option );
if ($help){
  &show_Help();
}
sub show_Help(){
  print "implement help message\n";
  print "l => lvname to use (instance01)\n";
  print "v => vganme to use (sysvg2)\n";
  print "o => option (create/delete/resize)\n";
  print "d => debug option\n";
  print "ex: mysql_makeLV.pl -o create -l instance01 -v sysvg2 -s 100G\n";
  exit 0;
}
# valid options: create, delete, resize
if (!$option){
  print "no option: create, delete, resize\n";
  &show_Help();
  exit 1;
}
if ($option eq "create"){
  &create_LV();
}elsif($option eq "delete"){
  &delete_LV();
}elsif($option eq "resize"){
  &resize_LV();
}else{
  print "unrecognized option\n";
  exit 1;
}
sub delete_LV(){
  print "delete not implemented\n";
  exit 0;
}
sub resize_LV(){
  print "resize not implemented\n";
  if (!$vg_name){
    $vg_name="sysvg2";
  }else{
    if (!-d "/dev/$vg_name"){
      my $show_vg=`/bin/vgs`;
      print "vg $vg_name is not present\n";
      print "Available VG's:\n$show_vg\n";
      exit 2;
    }
  }
  if (!$lv_name){
    print "no LV name to create\n";
    exit 1;
  }
  #grow xfs: xfs_growfs -L +100G /dev/sysvg/mongo
  exit 0;
}
sub create_LV(){
  print "create LV\n";
  if (!$vg_name){
    $vg_name="sysvg2";
  }
  if (!$lv_name){
    print "no LV name to create\n";
    exit 1;
  }else{
    if (!$lv_size){
      $lv_size="150G";
    }
    $lv_instance_name="$lv_name"."-instance";
    $lv_binlogs_name="$lv_name"."-logs";

    #check for bexisting LV before creating
    print "Creating LV $lv_instance_name on VG $vg_name with size $lv_size\n";
#create 10G /opt/mysql/binlong dir, then mount it later in script
# this is created on sysvg

    system("/usr/sbin/lvcreate -L +"."$lv_size"." -n"." $lv_instance_name $vg_name");
      $lvcreate_instance_rc=$?;
      if ($lvcreate_instance_rc != 0){
        #exit, failed to create;
      }
    print "Creating LV $lv_binlogs_name on VG sysvg with size 10G\n"; 
    system ("/usr/sbin/lvcreate -L +10G -n "."$lv_binlogs_name"." sysvg");
      $lvcreate_binlogs_rc=$?;
      if ($lvcreate_binlogs_rc !=0){
        #failed to create binlogs LV
      }
    print "Running mkfs.xfs on $lv_instance_name\n";
    system("/sbin/mkfs.xfs -i attr=2 -l version=2,size=64m,sunit=128 -d sunit=128,swidth=1024 /dev/"."$vg_name"."/"."$lv_instance_name");
      $mkfs_instance_rc=$?;
      if ($mkfs_instance_rc != 0){
        #delete created lv, then exit
      }
    print "Running mkfs.xfs on $lv_binlogs_name\n";
    system("/sbin/mkfs.xfs -i attr=2 -l version=2,size=64m,sunit=128 -d sunit=128,swidth=1024 /dev/sysvg/"."$lv_binlogs_name");
      $mkfs_instance_rc=$?;
      if ($mkfs_instance_rc != 0){
        #delete created lv, then exit
      }

    print "/bin/mkdir /opt/mysql/instance/"."$lv_name\n";
    system("/bin/mkdir -p /opt/mysql/instance/"."$lv_name");
#mkdir /opt/mysql/instance/$instance/db
      $mkdir_instance_rc=$?;
      if ($mkdir_instance_rc != 0){
        #mkdir failed. display error and exit
      }
    print "/bin/mkdir -p /opt/mysql/binlogs/"."$lv_name\n";
    system("/bin/mkdir -p /opt/mysql/binlogs/"."$lv_name");
      $mkdir_binlog_rc=$?;
      if ($mkdir_binlog != 0){
        #mkdir binlog failed                                                                                                             
      } 

    print "Mounting $lv_instance_name to /opt/mysql/instance/"."$lv_name\n";                                                             
    system("/bin/mount /dev/"."$vg_name"."/"."$lv_instance_name /opt/mysql/instance/"."$lv_name -t xfs");                                
      $mount_instance_rc=$?;                                                                                                             
      if ($mount_instance_rc != 0){                                                                                                      
        #mounting failed, display error and exit                                                                                         
      }                                                                                                                                  
     print "Mounting $lv_binlogs_name to /opt/mysql/binlogs/"."$lv_name\n";                                                              
     system("/bin/mount /dev/sysvg/"."$lv_binlogs_name /opt/mysql/binlogs/"."$lv_name -t xfs");                                          
       $mount_binlogs_rc=$?;                                                                                                             
       if ($mount_binlogs_rc != 0){                                                                                                      
         #mounting failed, display error and exit                                                                                        
       } 

    print "/bin/mkdir -p /opt/mysql/instance/"."$lv_name"."/db\n";
    system ("/bin/mkdir -p /opt/mysql/instance/"."$lv_name"."/db");
      $mkdir_db_rc=$?;
      if ($mkdir_db_rc != 0){
        # failed to create /opt/mysql/instance/db
      }
    print "/bin/mkdir -p /opt/mysql/binlogs/"."$lv_name"."/relay\n";
    system ("/bin/mkdir -p /opt/mysql/binlogs/"."$lv_name"."/relay");
      $mkdir_binlog_relay_rc=$?;
      if ($mkdir_binlog_relay_rc !=0){
        # mkdir /opt/mysql/binlog/lvname/relay failed
      } 
    print "/bin/mkdir -p /opt/mysql/binlogs/"."$lv_name"."/binlog\n";
    system("/bin/mkdir -p /opt/mysql/binlogs/"."$lv_name"."/binlog");
      $mkdir_binlog_binlog_rc=$?; 
print "binlog rc: $mkdir_binlog_binlog_rc\n\n";
      if ($mkdir_binlog_binlog_rc != 0){
        # mkdir /opt/mysq/binlogs/instance/binlog failed
      }
    print "ln -s /opt/mysql/binlogs/"."$lv_name"."/relay /opt/mysql/instance/"."$lv_name"."/db/relay\n";
    system("ln -s /opt/mysql/binlogs/"."$lv_name"."/relay /opt/mysql/instance/"."$lv_name"."/db/relay");
      $ln_relay=$?;
      if ($ln_relay != 0){
        # symlink to /opt/mysql/instance/lv_name/db/relay failed
      }
    print "ln -s /opt/mysql/binlogs/"."$lv_name"."/binlog /opt/mysql/instance/"."$lv_name"."/db/binlog\n";
    system("ln -s /opt/mysql/binlogs/"."$lv_name"."/binlog /opt/mysql/instance/"."$lv_name"."/db/binlog");
      $ln_binlog=$?;
      if ($ln_binlog != 0){
        # symlink to /opt/mysql/instance/lv_name/db/binlog failed
      }

    print "Chowning /opt/mysql/instance/"."$lv_name to mysql:dba\n";
    # test for dir first, then run chown
    system("/bin/chown -R mysql:dba /opt/mysql/instance/"."$lv_name");
      $chown_instance_rc=$?;
      if ($chown_instance_rc != 0){
        #display error and exit
      }
    print "Chowning /opt/mysql/binlogs/"."$lv_name to mysql:dba\n";
    system ("/bin/chown -R mysql:dba /opt/mysql/binlogs/"."$lv_name");
      $chown_binlogs_rc=$?;
      if ($chown_binlogs_rc != 0){
        #can't chown binlogs to mysql
      }
    print "Adding lv $lv_name_full mountpoint to /etc/fstab\n";
    open (FILE, ">>/etc/fstab");
    print FILE "/dev/"."$vg_name"."/"."$lv_instance_name"."\t"."/opt/mysql/instance/"."$lv_name"."\t"."xfs\tdefaults,nobarrier,inode64,attr2,noatime,nodiratime,allocsize=1g,logbufs=8,sunit=128,swidth=1024\t0\t0\n";
    print FILE "/dev/sysvg/"."$lv_binlogs_name"."\t"."/opt/mysql/binlogs/"."$lv_name"."\t"."xfs\tdefaults,nobarrier,inode64,attr2,noatime,nodiratime,allocsize=1g,logbufs=8,sunit=128,swidth=1024\t0\t0\n";
    close FILE;
  }
  # mkfs.xfs: mkfs.xfs -i attr=2 -l version=2,size=64m,sunit=128 -d sunit=128,swidth=1024 /dev/sysvg/mongo
  # mount: mount snapshot-mount -t xfs
  # /dev/sysvg/mongo	/opt/mongodb/instance	xfs	defaults,nobarrier,inode64,attr2,noatime,nodiratime,allocsize=1g,logbufs=8,sunit=128,swidth=1024	0	0

  exit 0;
}
