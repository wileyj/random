#!/usr/bin/env python
# requires working aws credentials(hard coded in .aws or iam profile)
# python snapshot.py --type clean-ami --retention 90 --dry-run
# python snapshot.py --type clean-ami --retention 90 --env stg --dry-run
# python snapshot.py --type clean-ami --retention 90 --volume  <id> --dry-run # discards args and creates a snapshot of the volume defined
# python snapshot.py --type clean-ami --retention 90 --instance <id> --dry-run # discards args and creates a snapshot of the instance defined
#
# python snapshot.py --type clean-snapshot --retention 90 --dry-run
# python snapshot.py --type clean-snapshot --retention 90 --env stg --dry-run # this won't work unless/until all snapshots are tagged with env. goddamned logicworks
# python snapshot.py --type clean-snapshot --retention 90 --volume <id> --dry-run # discards args and creates a snapshot of the volume defined
# python snapshot.py --type clean-snapshot --retention 90 --instance <id> --dry-run # discards args and creates a snapshot of the instance defined
#
# python snapshot.py --type clean-volume --retention 90 --dry-run
# python snapshot.py --type clean-volume --retention 90 --env stg --dry-run # this will ignore any other info and try to delete anything tagged 'stg'
# python snapshot.py --type clean-volume --retention 90 --volume  <id> --dry-run # discards args and creates a snapshot of the volume defined
# python snapshot.py --type clean-volume --retention 90 --instance <id> --dry-run # discards args and creates a snapshot of the instance defined
#
# python snapshot.py --type create-snapshot --dry-run # snapshots all volumes in-use and on a running host
# python snapshot.py --type create-snapshot --env stg --dry-run # create snapshot of volumes on all tagged stg instances
# python snapshot.py --type create-snapshot --volume <id> --dry-run # discards args and creates a snapshot of the volume defined
# python snapshot.py --type create-snapshot --instance <id> --dry-run # discards args and creates a snapshot of the instance defined
#
# python snapshot.py --type all --dry-run
# python snapshot.py --type all --env stg --dry-run


import boto3
from difflib import SequenceMatcher
from datetime import datetime, timedelta
import time
import argparse
import logging
import sys

instance_data = {}
image_data = {}
map_images = {}
image_snapshot = {}
snapshot_data = {}
snapshot_existing = {}
volume_data = {}
all_volumes = {}
snapshot_volumes = {}
volume_snapshot_count = {}
keep_snap = 1

def find_instances():
    """ find_instances function """
    logging.info("")
    logging.info("*** Retrieving instances")
    instances_vpc = sorted(
        client.describe_instances(
            Filters=[{
                'Name': 'vpc-id',
                'Values': ['*']
            },{
                'Name': 'instance-state-name',
                'Values': ['running', 'stopped']
            },{
                'Name': 'tag:Environment',
                'Values': [args.env]
            }]
        )['Reservations'],
            key=lambda x: (
                x['Instances'][0]['LaunchTime'],
                x['Instances'][0]['InstanceId']
            ),
            reverse=True
        )
    if not args.instance:
        instances_all = sorted(
            client.describe_instances(
                Filters=[{
                    'Name': 'instance-state-name',
                    'Values': ['running', 'stopped']
                },{
                    'Name': 'tag:Environment',
                    'Values': [args.env]
                }]
            )['Reservations'],
            key=lambda x: (
                x['Instances'][0]['LaunchTime'],
                x['Instances'][0]['InstanceId']
            ),
            reverse=True
        )
    else:
        instances_all = sorted(
            client.describe_instances(
                Filters=[{
                    'Name': 'instance-state-name',
                    'Values': ['running', 'stopped']
                },{
                    'Name': 'instance-id',
                    'Values': [args.instance]
                }]
            )['Reservations'],
            key=lambda x: (
                x['Instances'][0]['LaunchTime'],
                x['Instances'][0]['InstanceId']
            ),
            reverse=True
        )

    try:
        if len(instances_all) < 1:
            logging.debug("instances_all returned zero results...")
            logging.debug(instances_all)
    except:
        pass
    list_vpc = [item for item in instances_vpc ]
    list_all = [item for item in instances_all ]
    instance_without_vpc = [ item for item in instances_all  if item not in list_vpc ]
    running_count = 0
    stopped_count = 0
    for item in instances_all:
        t_name = ""
        t_env = ""
        t_vpc = ""
        platform = ""
        try:
            for tag in item['Instances'][0]['Tags']:
                if tag['Key'] == "Name":
                    t_name = tag['Value']
                if tag['Key'] == "Environment":
                    t_env = tag['Value']
        except:
            t_name = item['Instances'][0]['InstanceId']
        try:
            t_vpc = item['Instances'][0]['VpcId']
        except:
            t_vpc = "None"
        try:
            if item['Instances'][0]['Platform']:
                platform = item['Instances'][0]['Platform']
        except:
            platform = "Linux"
        try:
            if item['Instances'][0]['PrivateIpAddress']:
                private_ip_address = item['Instances'][0]['PrivateIpAddress']
        except:
            private_ip_address = "Undefined"
        try:
            if item['Instances'][0]['SubnetId']:
                subnet_id = item['Instances'][0]['SubnetId']
        except:
            subnet_id = "Undefined"
        instance_data[item['Instances'][0]['InstanceId']] = {
            'id': item['Instances'][0]['InstanceId'],
            'state': item['Instances'][0]['State']['Name'],
            'type': item['Instances'][0]['InstanceType'],
            'private_dns': item['Instances'][0]['PrivateDnsName'],
            'private_ip': private_ip_address,
            'launch_time': item['Instances'][0]['LaunchTime'],
            'image_id': item['Instances'][0]['ImageId'],
            'platform': platform,
            'subnet_id': subnet_id,
            'virt': item['Instances'][0]['VirtualizationType'],
            'name': t_name,
            'vpc': t_vpc,
            'environment': t_env,
            'volumes': []
        }
        if item['Instances'][0]['State']['Name'] == 'running':
            running_count = running_count + 1
        else:
            stopped_count = stopped_count + 1
        for volume in item['Instances'][0]['BlockDeviceMappings']:
            instance_data[item['Instances'][0]['InstanceId']]['volumes'].append(volume['Ebs']['VolumeId'])
        try:
            map_images[item['Instances'][0]['ImageId']] = {
                'imaged_id': item['Instances'][0]['ImageId'],
                'instance_id': [item['Instances'][0]['InstanceId']],
            }
        except:
            map_images[item['Instances'][0]['ImageId']]['instance_id'].append(item['Instances'][0]['InstanceId'])
    logging.info("\t Total VPC Instances: %s" % (len(list_vpc)))
    logging.info("\t Total Instances: %s" % (len(list_all)))
    logging.info("\t Total Classic Instances: %i" % (len(instance_without_vpc)))
    logging.info("\t Total Running Instances: %i" % (running_count))
    logging.info("\t Total Stopped Instances: %i" % (stopped_count))
    logging.info("\t Total Mapped Instances: %i" % (len(map_images)))
    logging.info("\t Items in instance_data dict: %i" % (len(instance_data)))
    return True

def find_images():
    """ find_images function """
    logging.info("")
    logging.info("*** Retrieving images")
    if args.env != "*":
        logging.info("\tDiscarding env arg for image retrieval")
    count_images = 0
    my_images = sorted(
        client.describe_images(
            Owners=[args.account_id]
        )['Images'],
        key=lambda x: (
            x['Name'],
            x['CreationDate']
        ),
        reverse=True
    )
    for x in my_images:
        count_images = count_images + 1
        set_buildmethod = False
        set_persist = False
        if not x['ImageId'] in map_images:
            logging.debug("[ INACTIVE ] %s ( %s )" % (x['ImageId'], x['Name']))
            # print "[ INACTIVE ] %s ( %s )" % (x['ImageId'], x['Name'])
            try:
                set_persist = False
                set_buildmethod = "undefined"
                try:
                    for t in x['Tags']:
                        if t['Key'] == "Persist":
                            set_persist = t['Value']
                            logging.debug("\tFound Persist Tag (%s) in image (%s)" % (set_persist, x['ImageId']))
                        if t['Key'] == "BuildMethod":
                            set_buildmethod = t['Value']
                except:
                    set_persist = False
                    set_buildmethod = "undefined"
                if set_persist == False:
                    ami_snapshot_existing = []
                    for index, this in enumerate(x['BlockDeviceMappings'], start=0):
                        try:
                            ami_snapshot_existing.append(this['Ebs']['SnapshotId'])
                        except:
                            pass
                    image_data[x['ImageId']] = {
                        'id': x['ImageId'],
                        'name': x['Name'],
                        'active': False,
                        'date': x['CreationDate'],
                        'persist': set_persist,
                        'build_method': set_buildmethod,
                        'snapshot_id': ami_snapshot_existing
                    }
            except:
                pass
        else:
            logging.debug("[ ACTIVE ]   %s ( %s )" % (x['ImageId'], x['Name']))
    logging.info("\tTotal Images Found: %i" % (count_images))
    logging.info("\tTotal Images tagged for deletion: %i" % (len(image_data)))
    return True

def find_snapshots():
    """" find_snapshots function """
    logging.info("")
    logging.info("*** Retrieving snapshots")
    count_deleted = 0
    my_snapshots = sorted(
        client.describe_snapshots(
            Filters=[{
                'Name': 'owner-id',
                'Values': [args.account_id]
            # },{
            #     'Name': 'tag:Environment',
            #     'Values': [args.env]
            }]
        )['Snapshots'],
        key=lambda x: (
            x['VolumeId'],
            x['StartTime']
        ),
        reverse=True
    )
    for item in my_snapshots:
        method = "undefined"
        try:
            if snapshot_existing[item['VolumeId']]:
                logging.debug("Found existing key for in snapshot_existing for %s" % (item['VolumeId']))
                pass
        except Exception:
            logging.debug("\tInitializing empty key/val for %s" % (item['VolumeId']))
            snapshot_existing[item['VolumeId']] = { 'snapshots': [] }
        try:
            volume_snapshot_count[item['VolumeId']] = { 'count': volume_snapshot_count[item['VolumeId']]['count'] + 1 }
        except:
            volume_snapshot_count[item['VolumeId']] = { 'count': 1 }
        epoch = int(item['StartTime'].strftime("%s"))
        diff = current_time - epoch
        age = diff/full_day
        snap_timestamp = "null"
        snap_persist = False
        try:
            for t in item['Tags']:
                if t['Key'] == "BuildMethod":
                    method = t['Value']
                if t['Key'] == "Timestamp":
                    snap_timestamp = t['Value']
                if t['Key'] == "Persist":
                    snap_persist = t['Value']
        except:
            pass
        match_ratio = SequenceMatcher(
            lambda item:
            item == " ",
            "Created by CreateImage(i-",
            item['Description']
        ).ratio()
        if match_ratio < 0.53 or match_ratio > 0.54:
            # not a snapshot created by an ami
            if age > args.retention and method != "Packer":
                count_deleted = count_deleted + 1
                try:
                    logging.debug("\t*** appending %s to  snapshot_exsting[ %s ]" % (item['SnapshotId'], item['VolumeId']))
                    snapshot_existing[item['VolumeId']]['snapshots'].append(item['SnapshotId'])
                except Exception:
                    logging.debug("*** Problem appending %s to  snapshot_exsting[ %s ]" % (item['SnapshotId'], item['VolumeId']))
                    pass
                # print "snap_count %s: %s" % (item['VolumeId'], volume_snapshot_count[item['VolumeId']]['count'] )
                snapshot_data[item['SnapshotId']] = {
                    'id': item['SnapshotId'],
                    'volume_id': item['VolumeId'],
                    'description': item['Description'],
                    'date': item['StartTime'],
                    'ratio': match_ratio,
                    'age': age,
                    'method': method,
                    'persist': snap_persist,
                    'timestamp': snap_timestamp,
                    'snap_count': volume_snapshot_count[item['VolumeId']]['count']
                }
        else:
            # snapshot created by an AMI (generically, don't delete these, except in the case of clean-images)
            image_snapshot[item['SnapshotId']] = {
                'id': item['SnapshotId'],
                'volume_id': item['VolumeId'],
                'description': item['Description'],
                'date': item['StartTime'],
                'ratio': match_ratio,
                'age': age,
                'method': method,
                'persist': snap_persist,
                'timestamp': snap_timestamp,
                'snap_count': volume_snapshot_count[item['VolumeId']]['count']
            }
    logging.info("\tTotal snapshots: %i" % (len(my_snapshots)))
    logging.info("\tTotal snapshots to retain: %i" % (len(my_snapshots) - len(snapshot_data) ))
    logging.info("\tTotal snapshots tagged for deletion: %i" % (len(snapshot_data)))
    return True

def find_volumes():
    """ find_volumes function """
    logging.info("")
    logging.info("*** Retrieving volumes")
    if not args.instance and not args.volume:
        my_volumes = client.describe_volumes()['Volumes']
    else:
        if args.instance:
            my_volumes = sorted(
                client.describe_volumes(
                    Filters=[{
                        'Name': 'volume-id',
                        'Values': instance_data[args.instance]['volumes']
                    }]
                )['Volumes'],
                key=lambda x: (
                    x['VolumeId']
                ),
                reverse=True
            )
        else:
            my_volumes = sorted(
                client.describe_volumes(
                    Filters=[{
                        'Name': 'volume-id',
                        'Values': [args.volume]
                    }]
                )['Volumes'],
                key=lambda x: (
                    x['VolumeId']
                ),
                reverse=True
            )
    # have to do something with args.env here.otherwise we will always try to backup all volumes, regardless of environment
    for volume in my_volumes:
        for attached in volume['Attachments']:
            all_volumes[volume['VolumeId']] = {
                'id': volume['VolumeId'],
                'attachment_id': attached['VolumeId'],
                'instance_id': attached['InstanceId'],
                'snapshot_id': volume['SnapshotId'],
                'device': attached['Device'],
                'state': volume['State'],
                'size': volume['Size'],
                'date': volume['CreateTime']
            }
            volume_snapshot_count[attached['VolumeId']] = { 'count': 0 }
            if is_candidate(volume['VolumeId'], attached['InstanceId']):
                logging.debug("\t\tCandidate Volume (%s, %s)" % (attached['InstanceId'] , volume['VolumeId']))
                if attached['InstanceId'] not in instance_data:
                    logging.debug("\t\tTagging Volume (%s, %s) for deletion" % (attached['InstanceId'], volume['VolumeId']))
                    volume_data[volume['VolumeId']] = {
                        'id': volume['VolumeId'],
                        'attachment_id': attached['VolumeId'],
                        'instance_id': attached['InstanceId'],
                        'snapshot_id': volume['SnapshotId'],
                        'device': attached['Device'],
                        'state': volume['State'],
                        'size': volume['Size'],
                        'date': volume['CreateTime']
                    }
            if len(volume['Attachments']) > 0:
                if args.hourly:
                    desc = short_hour
                else:
                    desc = short_date
                if args.persist:
                    persist = True
                else:
                    persist = False
                # here we flag a volume for backup
                if attached['InstanceId'] not in instance_data:
                    desc = desc+":"+attached['InstanceId']
                else:
                    desc = desc+":"+instance_data[attached['InstanceId']]['name'].replace(" - ", "-")
                desc = desc.replace(")", "")
                desc = desc.replace("(", "")
                desc = desc.replace(" ", "-")
                snapshot_volumes[volume['VolumeId']] = {
                    'id': volume['VolumeId'],
                    'instance_id': attached['InstanceId'],
                    'date': volume['CreateTime'],
                    'desc': desc+":"+attached['Device']+":"+volume['VolumeId'],
                    'old_desc': desc+":"+attached['Device'],
                    'persist': persist,
                    'hourly': args.hourly
                }
    logging.info("\tTotal Volumes discovered: %s" % (len(my_volumes)))
    logging.info("\tTotal Volumes tagged for deletion: %i" % (len(volume_data)))
    logging.info("\tTotal Volumes tagged for backup: %i" % (len(snapshot_volumes)))
    return True

def is_active_volume(instance_id):
    """ Determine if Volume is attached to running instance """
    logging.debug("\tChecking for disk usage on running host: %s" % (instance_id))
    if instance_id in instance_data:
        return True
    else:
        return False

def is_candidate(volume_id, instance_id):
    """ Make sure the volume is candidate for delete """
    if not is_active_volume(instance_id):
        metrics = get_metrics(volume_id)
        if len(metrics):
            for metric in metrics:
                if metric['Minimum'] < 299:
                    logging.debug("\t\tPassing Active Volume (%s, %s)" % (instance_id, volume_id))
                    return False
        return True
    else:
        # this is an active volume, we don't want to delete it automatically
        logging.debug("\t\tPassing Inactive Volume (%s, %s)" % (instance_id, volume_id))
        return False

def get_metrics(volume_id):
    """ Get volume idle time on an individual volume over `start_date` to today """
    volume_metrics_data = cloudwatch.get_metric_statistics(
        Namespace='AWS/EBS',
        MetricName='VolumeIdleTime',
        Dimensions=[{'Name': 'VolumeId', 'Value': volume_id}],
        Period=3600,
        StartTime=two_weeks,
        EndTime=today,
        Statistics=['Minimum'],
        Unit='Seconds'
    )
    logging.debug("\t\tReturning datapoints: %s" % (volume_metrics_data['Datapoints']))
    return volume_metrics_data['Datapoints']

def create_snapshot(volume_id, description, old_description, persist):
    """ Create snapshot of volume """
    # we don't want to delete snapshots from here after all
    # try:
    #     logging.debug("\tlen snapshot_existing: %i" % (len(snapshot_existing[volume_id]['snapshots'])))
    #     if len(snapshot_existing[volume_id]['snapshots']) != 0:
    #         for found_snapshot in snapshot_existing[volume_id]['snapshots']:
    #             delete_snapshot(found_snapshot, '')
    # except Exception:
    #     logging.debug("No snapshots exist for volume: %s" % (volume_id))
    #     pass
    try:
        if instance_data[all_volumes[volume_id]['instance_id']]['environment']:
            if instance_data[all_volumes[volume_id]['instance_id']]['state'] == "running":
                logging.info("\tCreating Snapshot of %s with Description: %s " % (volume_id, description))
                print "\tCreating tags:"
                print "\t\tName: %s" % (description)
                print "\t\tDepartment: %s" % ("Ops")
                print "\t\tInstanceId: %s" % (all_volumes[volume_id]['instance_id'])
                print "\t\tEnvironment: %s" % (instance_data[all_volumes[volume_id]['instance_id']]['environment'])
                print "\t\tPersist: %s\n" % (persist)
                return 1
            else:
                print "%s (%s)is not a running instance - %s" % (all_volumes[volume_id]['instance_id'], instance_data[all_volumes[volume_id]['instance_id']]['name'], instance_data[all_volumes[volume_id]['instance_id']]['state'])
                return 0
    except:
        print "%s doesn't exist in the list of active instances" % (all_volumes[volume_id]['instance_id'])
        return 0
    # create_snap = client.create_snapshot(
    #     VolumeId=volume_id,
    #     Description=description
    # )
    # client.create_tags(
    #     Resources=[create_snap['SnapshotId']],
    #     Tags = [{
    #         'Key': 'Name',
    #         'Value': description
    #     },{
    #         'Key': 'Department',
    #         'Value': 'Ops'
    #     },{
    #         'Key': 'InstanceId',
    #         'Value': all_volumes[volume_id]['instance_id']
    #     },{
    #        'Key': 'Environment',
    #        'Values': instance_data[all_volumes[volume_id]['instance_id']]['environment']
    #     },{
    #        'Key': 'Persist',
    #        'Values': persist
    #     }]
    # )
    return True

def delete_snapshot(snapshot_id, referrer):
    """ delete_snapshot """
    if not args.dry_run:
        # if args.type != "clean-images" and args.type != "clean-ami":
        if referrer == "delete_snapshot":
            if volume_snapshot_count[snapshot_data[snapshot_id]['volume_id']]['count'] > 1 and snapshot_data[snapshot_id]['persist'] == False:
                volume_snapshot_count[snapshot_data[snapshot_id]['volume_id']] = { 'count': volume_snapshot_count[snapshot_data[snapshot_id]['volume_id']]['count'] - 1 }
                logging.debug("\t\tDeleting snapshot %s" % (snapshot_id))
                return 1
            else:
                logging.debug("\t*** Preserving last snapshot of existing disk: %s %s" % (snapshot_data[snapshot_id]['volume_id'], snapshot_id))
                return 0
        else:
            logging.debug("\t%s)Deleting snapshot %s (%s)" % (args.type, snapshot_id, referrer))
            return 1
        # else:
        #     logging.debug("\tDeleting snapshot %s" % (snapshot_id))
        #     return 1
        # client.delete_snapshot(
        #     SnapshotId=snapshot_id
        # )
    else:
        logging.info("\t  dry run enabled...skipping snapshot deletion ( %s )" % (snapshot_id))
        return 0
    return False

def delete_image(ami_id, ami_name):
    """ deregister_image """
    if not args.dry_run:
        logging.debug("\tDeregistering Image: %s %s" % (ami_id, ami_name))
        # client.deregister_image(
        #     ImageId=ami_id
        # )
    else:
        logging.info("\t  dry run enabled...skipping image deletion ( %s %s)" % (ami_id, ami_name))
    return True

class Logging(object):
    # Logging formats
    _log_generic = '%(message)s'
    _log_simple_format = '%(asctime)s [%(levelname)s] %(message)s'
    _log_detailed_format = '%(asctime)s [%(levelname)s] [%(funcName)s:%(lineno)s] %(message)s'

    def configure(self, verbosity = None):
        ''' Configure the logging format and verbosity '''

        # Configure our logging output
        if verbosity >= 2:
            logging.basicConfig(level=logging.DEBUG, format=self._log_detailed_format, datefmt='%Y-%m-%d %H:%M:%S')
        elif verbosity >= 1:
            logging.basicConfig(level=logging.INFO, format=self._log_detailed_format, datefmt='%Y-%m-%d %H:%M:%S')
        else:
            logging.basicConfig(level=logging.INFO, format=self._log_generic, datefmt='%Y-%m-%d %H:%M:%S')

        # Configure Boto's logging output
        if verbosity >= 4:
            logging.getLogger('boto').setLevel(logging.DEBUG)
        elif verbosity >= 3:
            logging.getLogger('boto').setLevel(logging.INFO)
        else:
            logging.getLogger('boto').setLevel(logging.CRITICAL)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--type',
        choices=[
            "clean-ami",
            "clean-snapshot",
            "clean-snapshots",
            "clean-volume",
            "clean-volumes",
            "clean",
            "clean-images",
            "create-snapshot",
            "create-snapshots",
            "all"
        ],
        nargs='?',
        metavar='',
        default="",
        help="type",
        # required=True
    )
    parser.add_argument(
        '--region',
        choices=[
            "us-east-1",
            "us-west-1",
            "us-west-2",
            "ap-southeast-1"
            # etc
        ],
        nargs='?',
        metavar='',
        default="us-east-1",
        help="region",
        # required=True
    )
    parser.add_argument(
        '--account_id',
        nargs='?',
        metavar='',
        default="111111111111",
        help="account_id"
    )
    parser.add_argument(
        '-v',
        dest='verbose',
        nargs='?'
    )
    parser.add_argument(
        '--volume',
        nargs='?',
        default="",
        help="VolumeID"
    )
    parser.add_argument(
        '--instance',
        nargs='?',
        default="",
        help="InstanceID"
    )
    parser.add_argument(
        '--retention',
        nargs='?',
        default=30,
        type=int,
        help="Retention"
    )
    parser.add_argument(
        '--hourly',
        action='store_true',
        help="Hourly"
    )
    parser.add_argument(
        '--persist',
        action='store_true',
        help="Persist"
    )
    parser.add_argument(
        '--env',
        choices=[
            "dev",
            "staging",
            "stg",
            "production",
            "prod",
            "prd"
        ],
        nargs='?',
        metavar='',
        default="*",
        help="Environment"
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help="DryRun"
    )

    args = parser.parse_args()
    if not args.type:
        print parser.print_help()
        exit(3)
    if args.env == "prod" or args.env == "prd":
        args.env = "production"
    if args.env == "stg":
        args.env = "staging"
    Logging().configure(args.verbose)
    # __all__ = ('snapshot', 'Logging')
    __all__ = ( 'Logging')
    logging = logging.getLogger(__name__)
    region = args.region
    client = boto3.client('ec2', region_name=region)
    cloudwatch = boto3.client('cloudwatch', region_name=region)
    current_time = int(round(time.time()))
    full_day = 86400
    time_diff = args.retention * full_day
    today = datetime.now()
    tomorrow = datetime.now() + timedelta(days=1)
    yesterday = datetime.now() - timedelta(days=1)
    two_weeks = datetime.now() - timedelta(days=14)
    four_weeks = datetime.now() - timedelta(days=28)
    thirty_days = datetime.now() - timedelta(days=30)

    retention_day = timedelta(days=args.retention)
    start_date = today - retention_day
    short_date = str('{:04d}'.format(today.year))+str('{:02d}'.format(today.month))+str('{:02d}'.format(today.day))
    short_hour = str('{:04d}'.format(today.year))+str('{:02d}'.format(today.month))+str('{:02d}'.format(today.day))+"_"+str(current_time)
    if args.volume and args.instance:
        logging.info("false. only one option is allowed")
        exit(1)
    if args.volume or args.instance:
        args.type = "create-snapshot"
    logging.info("")
    logging.info("*** Timing ***")
    logging.info("\tCurrent time: %i" % (current_time))
    logging.info("\tRetention: %i" % (args.retention))
    logging.info("\tFull day in seconds: %i" % (full_day))
    logging.info("\tToday: %s" % (str(today)))
    logging.info("\tTomorrow: %s" % (str(tomorrow)))
    logging.info("\tYesterday: %s" % (str(yesterday)))
    logging.info("\t2 Weeks Ago: %s" % (str(two_weeks)))
    logging.info("\t4 Weeks Ago: %s" % (str(four_weeks)))
    logging.info("\t30 Days Ago: %s" % (str(thirty_days)))
    logging.info("\tRetention Time: %s" % (str(retention_day)))
    logging.info("\tStart Date: %s" % (str(start_date)))
    logging.info("\tShort Date: %s" % (short_date))
    logging.info("\tShort Hour: %s" % (short_hour))
    logging.info("")
    logging.info("*** Defined Args ***")
    logging.info("\targs.verbose: %s" % (args.verbose))
    logging.info("\targs.type: %s" % (args.type))
    logging.info("\targs.env: %s" % (args.env))
    logging.info("\targs.volume: %s" % (args.volume))
    logging.info("\targs.instance: %s" % (args.instance))
    logging.info("\targs.retention: %s" % (args.retention))
    logging.info("\targs.dry_run: %s" % (args.dry_run))
    find_instances()
    if not args.volume and not args.instance:
        if args.type != "clean-snapshot" or args.type != "clean-snapshots" or args.type != "clean-volume" or args.type != "clean-volumes":
            find_images()
    find_volumes()
    if args.type != "create-snapshot" or args.type != "create-snapshots":
        find_snapshots()
    if args.type == "all" or args.type == "clean-snapshot" or args.type == "clean-snapshots" or args.type == "clean":
        snapshot_count = 0
        logging.debug("\n\n")
        logging.debug("Ignoring any env flag for cleanup: %s" % (args.env))
        logging.info("*** Cleaning Snapshots ***")
        logging.info(" - volume_snapshot_count %i" % len(snapshot_data))
        for snapshot in snapshot_data:
            if snapshot_data[snapshot]['volume_id'] not in all_volumes:
                delete_snapshot(snapshot_data[snapshot]['id'], '')
                snapshot_count = snapshot_count + 1
            else:
                if snapshot_data[snapshot]['snap_count'] > keep_snap and not snapshot_data[snapshot]['persist']:
                    logging.debug("")
                    logging.debug("snap_id: %s" % (snapshot_data[snapshot]['id']))
                    logging.debug("\tsnap_vol: %s" % (snapshot_data[snapshot]['volume_id']))
                    logging.debug("\tsnap_desc: %s" % (snapshot_data[snapshot]['description']))
                    logging.debug("\tsnap_date: %s" % (snapshot_data[snapshot]['date']))
                    logging.debug("\tsnap_ratio: %s" % (snapshot_data[snapshot]['ratio']))
                    logging.debug("\tsnap_age: %s" % (snapshot_data[snapshot]['age']))
                    logging.debug("\tsnap_persist: %s" % (snapshot_data[snapshot]['persist']))
                    logging.debug("\tsnap_method: %s" % (snapshot_data[snapshot]['method']))
                    logging.debug("\tsnap_count: %s" % (snapshot_data[snapshot]['snap_count']))
                    delete_snapshot(snapshot_data[snapshot]['id'], 'delete_snapshot')
                    snapshot_count = snapshot_count + 1
                else:
                    logging.debug("")
                    logging.info("snap_id: %s" % (snapshot_data[snapshot]['id']))
                    logging.info("\tignoring deletion of %s...count:(%s:%s)" % (snapshot_data[snapshot]['id'], snapshot_data[snapshot]['snap_count']), volume_snapshot_count[snapshot_data[snapshot]['volume_id']]['count'])
        logging.info("   *** Total Snapshots Deleted: %s" % (snapshot_count))

    if args.type == "all" or args.type == "clean-volume" or args.type == "clean-volumes" or args.type == "clean":
        volume_count = 0
        logging.debug("\n\n")
        logging.debug("Ignoring any env flag for cleanup: %s" % (args.env))
        logging.info("*** Cleaning Volumes ***")
        logging.info("*** Note: this is info only ***\n")
        for volume in volume_data:
            volume_count = volume_count + 1
            logging.debug("")
            logging.debug("volume_id: %s" % (volume_data[volume]['id']))
            logging.debug("\tvolume_instance_id: %s" % (volume_data[volume]['instance_id']))
            logging.debug("\tvolume_date: %s" % (volume_data[volume]['date']))
        logging.info("   *** Total Volumes To Delete: %s" % (volume_count))

    if args.type == "all" or args.type == "clean-ami" or args.type == "clean" or args.type == "clean-images" :
        image_count = 0
        logging.debug("\n\n")
        logging.debug("Ignoring any env flag for cleanup: %s" % (args.env))
        logging.info("*** Cleaning Images ***")
        for image in image_data:
            image_count = image_count + 1
            logging.debug("")
            logging.debug("ami_id: %s" % (image_data[image]['id']))
            logging.debug("\tami_name: %s" % (image_data[image]['name']))
            logging.debug("\tami_attachment_id: %s" % (image_data[image]['date']))
            logging.debug("\tami_snapshot_id: %s" % (image_data[image]['snapshot_id']))
            logging.debug("\tami_persist: %s" % (image_data[image]['persist']))
            logging.debug("\tami_build_method: %s" % (image_data[image]['build_method']))
            if not image_data[image]['persist']:
                for ami_snapshot in image_data[image]['snapshot_id']:
                    delete_snapshot(ami_snapshot, 'delete_image')
                delete_image(image_data[image]['id'], image_data[image]['name'])
        logging.info("   *** Total Images Deregistered: %s" % (image_count))

    if args.type == "all" or args.type == "create-snapshot" or args.type == "create-snapshots":
        snapshot_count = 0
        logging.debug("\n\n")
        logging.info("*** Creating Snapshots ***")
        for s_volume in snapshot_volumes:
            logging.debug("")
            logging.debug("\tsnapshot_volume['volume_id']: %s" % (snapshot_volumes[s_volume]['id']))
            logging.debug("\tsnapshot_volume['instance_id']: %s" % (snapshot_volumes[s_volume]['instance_id']))
            logging.debug("\tsnapshot_volume['date']: %s" % (snapshot_volumes[s_volume]['date']))
            logging.debug("\tsnapshot_volume['desc']: %s" % (snapshot_volumes[s_volume]['desc']))
            logging.debug("\tsnapshot_volume['old_desc']: %s" % (snapshot_volumes[s_volume]['old_desc']))
            logging.debug("\tsnapshot_volume['persist']: %s" % (snapshot_volumes[s_volume]['persist']))
            logging.debug("\tsnapshot_volume['hourly']: %s" % (snapshot_volumes[s_volume]['hourly']))
            snapshot_count = snapshot_count +create_snapshot(snapshot_volumes[s_volume]['id'], snapshot_volumes[s_volume]['desc'], snapshot_volumes[s_volume]['old_desc'], snapshot_volumes[s_volume]['persist'])
        logging.info("   *** Total Volumes to Snapshot: %s" % (snapshot_count))
