#!/usr/bin/python
#
#    python beanstalk.py --region "us-west-1" --app "steppers-dev-1" 
#
#    python beanstalk.py --region "us-west-1" --app "steppers-dev-1" --scaleup
#    python beanstalk.py --region us-east-1 --app Slots-Dev-2 --scaleup --maxsize 6
#    
#    python beanstalk.py --region "us-west-1" --app "steppers-dev-1" --scaledown
#    python beanstalk.py --region us-east-1 --app Slots-Dev-2 --scaledown --maxsize 2
#


import boto3, json, argparse, os, operator, jinja2, logging, time, sys
from   difflib import SequenceMatcher
from   jinja2  import Environment, FileSystemLoader
from   pprint  import pprint

env = {
    'prod'    : "production",
    'staging' : "staging",
    'dev'     : "dev"
}
epoch = int(time.time())
secs=1
default_scaleup = 10
default_scaledown = 3

def stack_status(stack, region):
    client = boto3.client('cloudformation', region_name=region)
    response = client.list_stacks(StackStatusFilter=['DELETE_IN_PROGRESS'])['StackSummaries']
    if len(response) > 0:
        for item in response:
            if item['StackName'] == stack:
                response2 = client.describe_stacks( StackName=item['StackName'],)['Stacks']
                return (response2[0]['StackStatus'])
    return "null"
 
def env_terminate(stack, region):
    client = boto3.client('cloudformation', region_name=region)
    response = client.delete_stack(StackName=stack)
    elapsed=0
    while stack_status(stack, region) == "DELETE_IN_PROGRESS":
        status = stack_status(stack, region)
        elapsed = elapsed + secs
        sys.stdout.write("[ INFO  ] - Terminating %s Stack: (%s) %ss elapsed \r" % (stack, status, elapsed) )
        sys.stdout.flush()
        time.sleep(secs)
    print "\n[ INFO  ] - Terminated %s \n" % (stack)
    exit (0)

def env_status(env, region):
    client   = boto3.client('elasticbeanstalk', region_name=region)
    response = client.describe_environment_health( EnvironmentName=env, AttributeNames=['Status'] )
    if len(response) > 0:
        return response['Status']
    else:
        return "null"

def app_status(app, region, env):
    client   = boto3.client('elasticbeanstalk', region_name=region)
    response = client.describe_environments(ApplicationName=app)['Environments']
    returned = "null"
    if len(response) > 0:
        for i in response:
            if i['EnvironmentName'] == env:
                if i['Status'] != "Terminated" and i['Status'] != "Terminating":
                    returned=i['Status']
    return returned

def write_template(type, template_values, template):
    print "[ EXEC  ] - Writing Template %s" % (template)
    env       = jinja2.Environment(loader=jinja2.FileSystemLoader(["./templates"]))
    template  = env.get_template( template)
    result    = template.render( template_values)
    name      = template_values['app_name'].title() + "-" + template_values['env_short'].title() + "-" + template_values['app_version']
    json_file = "/var/tmp/cf.json"
    os.open(json_file, os.O_CREAT)
    fd        = os.open(json_file, os.O_RDWR)
    os.write(fd, result)
    file_stat = os.fstat(fd)
    os.close(fd)
    client   = boto3.client('cloudformation', region_name=template_values['region'])
    print "[ INFO  ] - Wrote Template with size: ", file_stat.st_size
    if type == "env":
        print "[ EXEC  ] - Launching New Stack Named Application: %s" % (name)
        sqs_arn   = "arn:aws:sns:"+template_values['region']+":"+template_values['account']+":"+template_values['app_name'].title()+"-"+template_values['env_short'].title()
        cf_stack = client.create_stack(
            StackName        = name,
            TemplateBody     = result,
            TimeoutInMinutes = 30,
            NotificationARNs = [ sqs_arn ],
            Capabilities     = [ 'CAPABILITY_IAM' ],
            OnFailure        = 'DELETE'
        )
    else:
        print "[ EXEC  ] - Launching New Stack Named Environment: %s" % (name)
        cf_stack = client.create_stack(
            StackName        = name,
            TemplateBody     = result,
            TimeoutInMinutes = 30,
            Capabilities     = [ 'CAPABILITY_IAM' ],
            OnFailure        = 'DELETE'
        )
    secs=1
    elapsed=0
    b_app = template_values['app_name'].lower()+"-"+template_values['env_short'].lower()
    b_env = b_app + "-" + template_values['app_version']
    while app_status(b_app, template_values['region'], b_env) == "null":
        if elapsed < 30:
            status = app_status(b_app, template_values['region'], b_env)
            elapsed = elapsed + secs
            sys.stdout.write("[ INFO  ] - Waiting for Environment to start launching %ss elapsed \r" % (elapsed) )
            sys.stdout.flush()
            time.sleep(secs)
        else:
            print "\nOperation Timed out after %is: " % (elapsed)
            exit (-10)
    print "\n"
    elapsed=0
    env_status(name,template_values['region'])
    while env_status(name,template_values['region']) != "Ready":
        if elapsed < 600:
            status = env_status(name,template_values['region'])
            sys.stdout.write("[ INFO  ] - Creating Beanstalk: (%s) %ss elapsed \r" % (status, elapsed) )
            sys.stdout.flush()
            time.sleep(secs)
            elapsed = elapsed + secs
        else:
            print "\nOperation Timed out after %is: " % (elapsed)
            exit (-10)
    client               = boto3.client('s3')
    s3                   = boto3.resource('s3')
    s3_file_name         = name+"."+str(int(time.time()))+".json"
    s3.create_bucket(ACL = 'authenticated-read',Bucket=args.bucket)
    s3.Bucket(args.bucket).upload_file(json_file, s3_file_name)
    response             = client.get_object(Bucket=args.bucket, Key=s3_file_name)
    uploaded_size        = response['ContentLength']
    print "\n[ INFO  ] - Uploaded File Size: ", uploaded_size
    if uploaded_size == file_stat.st_size:
        print "[ INFO  ] - Uploaded filesize (%s) Matches local filesize (%s)" % (uploaded_size, file_stat.st_size)
        print "            Deleting Local file %s " % (json_file)
        os.remove(json_file)
        exit (0)
    else:
        print "[ ERROR ] - Uploaded file size doesn't match local file size "
        print "            Local:  %s size: %s" % (json_file, file_stat.st_size)
        print "            Remote: %s size: %s" % (s3_file_name, uploaded_size)
        exit (-4)

def launch_environment(app):
    values = {
        'warfile'        : warfile,
        'version_label'  : version_label,
        'solution_stack' : solution_stack,
        'region'         : region,
        'app'            : app,
        'minsize'        : minsize,
        'maxsize'        : maxsize,
        'lower'          : lower,
        'upper'          : upper,
        'health_type'    : health_type,
        'ssl_cert'       : ssl_cert,
        'keyname'        : keyname,
        'env_short'      : env_short,
        'app_lower'      : app_lower,
        'app_name'       : app_name,
        'environment'    : environment,
        'app_version'    : app_version,
        'app_arn'        : app_arn,
        'keyname'        : keyname,
        'instance'       : instance,
        'account'        : account,
        'service_role'   : service_role,
    }
    print "[ EXEC  ] - Creating Environment Template For %s" % (app)
    write_template("env", values,"cf.j2")

def launch_application(app):
    print "[ EXEC ] - Launching New Application: %s" % (app)
    app_name = app.split("-")[0].lower()
    app_env = app.split("-")[1].lower()
    values = {
        'region'         : args.region,
        'Environment'    : app_env,
        'app_name'       : app_name,
        'app_version'    : 'env',
        'SNSTopicName'   : app_name.title()+"-"+app_env.title(),
        'SNSDisplayName' : app_name.title()+"-"+app_env.title(),
        'account'        : args.account,
        'env_short'      : env_short,
    }
    print "[ EXEC  ] - Creating Application Template For %s" % (app)
    write_template("app", values,"cf-env.j2")

def get_stack(region):
    client = boto3.client('elasticbeanstalk', region_name=region)
    stacks = client.list_available_solution_stacks()
    available = stacks['SolutionStacks']
    x={}
    if available:
        for item in available:
            diff = SequenceMatcher(None, "running Tomcat", item).ratio()
            if 0.39 < diff < 0.40:
                x[item] = item
        sorted_x = sorted(x.items(), key=operator.itemgetter(1), reverse=True)
        logging.debug("Length of Solution Stack List: %s" % (len(sorted_x)))
        if  len(sorted_x) == 0:
            print "\n[ ERROR ] - No Tomcat Solution Stacks found in  %s" % (region)
            print "            Cowardly Refusing to Continue\n"
            exit (-1)
        solution_stack = sorted_x[0][0]
    else:
        print "\n[ ERROR ] - No Solution Stacks Found in %s" % (region)
        print "            Cowardly Refusing to Continue\n"
        exit (-4)
    return solution_stack

def get_war(region,appname,environment,app):
    bucketname="netflix-deploy-" + region
    logging.debug("get_war var (region):      %s" % (region))
    logging.debug("get_war var (appname):     %s" % (appname))
    logging.debug("get_war var (environment): %s" % (environment))
    logging.debug("get_war var (app):         %s" % (app))
    logging.debug("get_war env long-name:     %s" % (env[environment]))
    logging.debug("S3 Bucket Name:            %s" % (bucketname))
    warfile               = ""
    found_app             = 0
    x                     = {}
    client                = boto3.client('elasticbeanstalk', region_name=region)
    app_versions          = client.describe_application_versions(ApplicationName=appname)
    env_app_list          = app_versions['ApplicationVersions']
    describe_environments = client.describe_environments(ApplicationName=appname, EnvironmentNames=[app], IncludeDeleted=False)
    r_env                 = describe_environments['Environments']
    describe_applications = client.describe_applications(ApplicationNames=[appname])
    r_app                 = describe_applications['Applications']
    logging.debug("Number of Matching Environments Found matching %s: %s" % (app, str(len(r_env))))
    logging.debug("Number of Matching Applications Found matching %s: %s" % (appname, str(len(r_app))))
    if len(r_app) > 0 and len(r_env) >0:
        if r_env[0]['Status'] != "Terminated":
            print "\n[ ERROR ] - Application Environment %s Already Exists in %s" % (app,appname)
            print "              Cowardly Refusing to Continue\n"
            exit (-3)
    if len(r_app) == 0:
        print "\n[ ERROR ] - Application %s Doesn't Exist yet" % (appname)
        print "[ INFO  ] - Creating Application Launch Template for %s" % (appname)
        launch_application(appname)

    if len(env_app_list) > 0:
        print "\n[ INFO  ] - Looking in Beanstalk for the newest Warfile: "
        for app in env_app_list:
            if app['ApplicationName'] == appname:
                x[app['DateCreated']] = app['SourceBundle']['S3Key']
                found_app=1
        sorted_x = sorted(x.items(), key=operator.itemgetter(0), reverse=True)
        if len(sorted_x) != 0:
            warfile=sorted_x[0][1]

    if len(warfile) == 0 and len(env_app_list) < 1:
        print "[ INFO  ] - Looking in S3 for the newest Warfile"
        client = boto3.client('s3', region_name=args.region)
        client = boto3.client('s3')
        bucket_name = bucketname
        p = "rtg-root-"+env_short
        if appname.split("-")[0].lower() == "steppers":
            p = "rtg-steppers-root-"+env_short
        if appname.split("-")[0].lower() == "tournament":
            p = "rtg-tournament-root-"+env_short
        prefix = p+"-"+environment
        logging.debug("Bucket Prefix: %s" % (prefix))
        response = client.list_objects(
            Bucket=bucket_name,
            Prefix=p,
        )['Contents']
        if response:
            for item in response:
                x[item['Key']] = item['LastModified']
            sorted_x     = sorted(x.items(), key=operator.itemgetter(0), reverse=True)
        else:
            print "\n[ ERROR ] - No Warfiles "
            print "            Cowardly Refusing to Continue\n"
            exit (-1)
        if len(sorted_x) == 0:
            print "\n[ ERROR ] - List of S3 Applications is empty\n"
            print "            Cowardly Refusing to Continue\n"
            exit (-5)
        else:
            warfile=sorted_x[0][0]
    if  len(warfile) == 0:
        print "\n[ ERROR ] - No Warfile found in Beanstalk or S3 for %s in %s" % (appname, region)
        print "            Cowardly Refusing to Continue\n"
        exit (-1)
    else:
        return warfile

def scale(num,app,env,region):
    print "[ INFO  ] - Scaling %s to %s nodes" % (env, num)
    client = boto3.client('elasticbeanstalk', region_name=region)
    response = client.update_environment(
        ApplicationName=app,
        EnvironmentName=env,
        OptionSettings=[{
            "Namespace"  : "aws:autoscaling:asg",
            "OptionName" : "MinSize",
            "Value"      : num
        }, {
            "Namespace"  : "aws:autoscaling:asg",
            "OptionName" : "MaxSize",
            "Value"      : num
        }]
    )
    elapsed=0
    secs=1
    while env_status(env, region) != "Ready":
        status = env_status(env, region)
        elapsed = elapsed + secs
        sys.stdout.write("[ INFO  ] - Updating %s Beanstalk: (%s) %ss elapsed \r" % (env, status, elapsed) )
        sys.stdout.flush()
        time.sleep(secs)
    print "[ INFO  ] - %s Finshed Scaling" % (env)
    print "\n"
    exit (0)

class VAction(argparse.Action):
    def __call__(self, parser, args, values, option_string=None):
        # print 'values: {v!r}'.format(v=values)
        if values==None:
            values='1'
        try:
            values=int(values)
        except ValueError:
            values=values.count('v')+1
        setattr(args, self.dest, values)

if __name__ == "__main__":
    clear = lambda: os.system('clear')
    clear()
    parser = argparse.ArgumentParser()
    parser.add_argument('--region',        metavar='', default="", help='AWS Region ( us-west-1, us-west-2, us-east-1 )')
    parser.add_argument('--stack',         metavar='', default="", help='Beanstalk Solution Stack' )
    parser.add_argument('--app',           metavar='', default="", help='Beanstalk Environment Name ( Slots-Prod-1 )' )
    parser.add_argument('--env',           metavar='', default="", help='Environment ( dev, staging, prod )' )
    parser.add_argument('--minsize',       metavar='', default="3", help='Beanstalk Minimum Number of EC2 Instances ( 3 )' )
    parser.add_argument('--maxsize',       metavar='', default="3", help='Beanstalk Minimum Number of EC2 Instances ( 3 )' )
    parser.add_argument('--lower',         metavar='', default="5500000", help='AutoScaling scale down metric ( 5500000 )' )
    parser.add_argument('--upper',         metavar='', default="5500000000000", help='AutoScaling scale up metric ( 5500000000000 )' )
    parser.add_argument('--health',        metavar='', default="enhanced", help='Instance Health Type ( basic, enhanced )' )
    parser.add_argument('--cert',          metavar='', default="wildcard.risingtidegames.com", help='SSL Certificate ( wildcard.risingtidegames.com )' )
    parser.add_argument('--keyname',       metavar='', default="rtg", help='AWS EC2 Keyname ( rtg )' )
    parser.add_argument('--instance',      metavar='', default="m4.large", help='EC2 Instance Type ( m3.medium ) ' )
    parser.add_argument('--account',       metavar='', default="480352787924", help='AWS Account Number ( 480352787924 ) ' )
    parser.add_argument('--service_role',  metavar='', default="aws-elasticbeanstalk-service-role", help='Beanstalk EC2 Service Role (aws-elasticbeanstalk-service-role)' )
    parser.add_argument('--bucket',        metavar='', default="netflix-cloudformation", help="Bucket To store Cloudformation Json ( netflix-cloudformation ) " )
    parser.add_argument('--scaleup',       nargs='?',  default='', help="Scale the Beanstalk Env Up ( Default 10 )")
    parser.add_argument('--scaledown',     nargs='?',  default='', help="Scale the Beanstalk Env Down ( Default 3 )")
    parser.add_argument('--terminate',     metavar='', default='', help="Terminate the specified beanstalk env. Requires a 'Yes' arg")
    parser.add_argument('-v',              nargs='?',  action=VAction, dest='verbose')
    args = parser.parse_args()
    if args.verbose:
        if args.verbose == 4:
            logging.basicConfig(level=logging.DEBUG)
        elif args.verbose == 3:
            logging.basicConfig(level=logging.INFO)
        elif args.verbose == 2:
            logging.basicConfig(level=logging.WARNING)
        else:
            logging.basicConfig(level=logging.ERROR)
    if not (args.region) or not(args.app):
        print "\n[ ERROR ] - region and app args are required"
        print "              Cowardly Refusing to Continue\n"
        parser.print_help()
        exit(-1)
    token=args.app.split("-")
    if token > 2:
        args.app_lower   = args.app.lower()
        args.app_name    = args.app_lower.split("-")[0]
        args.app_env     = args.app_lower.split("-")[1]
        args.app_version = args.app_lower.split("-")[2]
        args.app_arn     = args.app.split("-")[0].title() + "-" + args.app.split("-")[1].title()
        if not args.app_env in env:
            print "\n[ ERROR ] - Environment %s not found" % (args.app_env)
            print "              Cowardly Refusing to Continue\n"
            exit (-3)
        if not args.app_version.isdigit():
            print "\n[ ERROR ] - Bad Format for App %s " % (args.app)
            print "              ex: Slots-Prod-1"
            print "              Cowardly Refusing to Continue\n"
            parser.print_help()
            exit (-4)
        args.beanstalk = args.app_name + "-" + env[args.app_env]
    else:
        print "\n[ ERROR ] - App Name is wrong format: ", args.app
        print "              ex: Slots-Prod-1"
        print "              Cowardly Refusing to Continue\n"
        parser.print_help()
        exit(-1)

    if args.terminate:
        if args.terminate == "Yes":
            print "\n[ INFO  ] - Looking for stack %s in %s" % (args.beanstalk, args.region)
            if app_status(args.beanstalk, args.region, args.app_lower) != "null":
                print "[ INFO  ] - Found exisiting stack %s. continuing..." % (args.beanstalk)
                env_terminate(args.app, args.region)
        else:
            print "\n[ ERROR ] - In order to terminate a named stack, you need to supply a 'Yes' argument"
            exit(-10)

    if args.scaleup != "" and args.scaledown == "":
        print "\n[ INFO  ] - Scaling Up Beanstalk %s in %s" % (args.app_lower, args.region)
        if args.maxsize != 3:
            num = args.maxsize
        else:
            num = default_scaleup
        print "[ INFO  ] - Scaling Up to %s nodes" % (num)
        if app_status(args.beanstalk, args.region, args.app_lower) != "null":
            scale(num,args.beanstalk,args.app_lower,args.region)
        else:
            print "[ ERROR ] - Beanstalk %s in %s Not Found" % (args.app_lower, args.region)

    if args.scaledown != "" and args.scaleup == "":
        print "\n[ INFO  ] - Scaling Down Beanstalk %s in %s" % (args.app_lower, args.region)
        if args.maxsize != 10:
            num = args.maxsize
        else:
            num = default_scaledown
        print "[ INFO  ] - Scaling Down to %s nodes" % (num)
        if app_status(args.beanstalk, args.region, args.app_lower) != "null":
            scale(num,args.beanstalk,args.app_lower,args.region)
        else:
            print "[ ERROR ] - Beanstalk %s in %s Not Found" % (args.app_lower, args.region)

    if not (args.stack):
        args.stack = get_stack(args.region)

    j2_env = Environment(
        loader      = FileSystemLoader(os.path.dirname(__file__)),
        extensions  = ['jinja2.ext.autoescape'],
        autoescape  = True,
        trim_blocks = True,
    )
    solution_stack = args.stack
    region         = args.region
    app            = args.app
    minsize        = args.minsize
    maxsize        = args.maxsize
    lower          = args.lower
    upper          = args.upper
    health_type    = args.health
    ssl_cert       = args.cert
    keyname        = args.keyname
    env_short      = args.app_env
    app_lower      = args.app_lower
    app_name       = args.app_name
    environment    = env[args.app_env]
    app_version    = args.app_version
    app_arn        = args.app_arn
    keyname        = args.keyname
    instance       = args.instance
    account        = args.account
    service_role   = args.service_role
    war_file       = get_war(args.region,args.beanstalk,args.app_env, args.app)
    warfile        = war_file
    version_label  = war_file.split(".")[0].split("-")[3]

    launch_environment(args.app)

    logging.debug("\tWarfile:              %s" % (warfile))
    logging.debug("\tVersion Label:        %s" % (version_label))
    logging.debug("\tSolution Stack:       %s" % (solution_stack))
    logging.debug("\tAWS Region:           %s" % (region))
    logging.debug("\tApp Env:              %s" % (app))
    logging.debug("\tEC2 Minsize:          %s" % (minsize))
    logging.debug("\tEC2 Maxsize:          %s" % (maxsize))
    logging.debug("\tASG Lower Threshold:  %s" % (lower))
    logging.debug("\tASG Upper Threshold:  %s" % (upper))
    logging.debug("\tEC2 Health Type:      %s" % (health_type))
    logging.debug("\tELB SSL Cert:         %s" % (ssl_cert))
    logging.debug("\tEC2 Keyname:          %s" % (keyname))
    logging.debug("\tEC2 Environment Name: %s" % (env_short))
    logging.debug("\tApp Env (lowercase):  %s" % (app_lower))
    logging.debug("\tEnv Name:             %s" % (app_name))
    logging.debug("\tEnv Stage:            %s" % (environment))
    logging.debug("\tEnvironment Version:  %s" % (app_version))
    logging.debug("\tSQS Env ARN:          %s" % (app_arn))
    logging.debug("\tEC2 Instance Type:    %s" % (instance))
    logging.debug("\tAWS Account:          %s" % (account))
    logging.debug("\tService Role:         %s" % (service_role))
    logging.debug("\tBeanstalk App Name:   %s" % (args.beanstalk))

    # Warfile:              rtg-root-dev-3fa94783cbc966596a8d1b3c1f3bcd77.zip
    # Version Label:        3fa94783cbc966596a8d1b3c1f3bcd77
    # Solution Stack:       64bit Amazon Linux 2015.09 v2.0.4 running Tomcat 8 Java 8
    # AWS Region:           us-east-1
    # App Env:              Slots-Dev-3
    # EC2 Minsize:          3
    # EC2 Maxsize:          3
    # ASG Lower Threshold:  5500000
    # ASG Upper Threshold:  5500000000000
    # EC2 Health Type:      enhanced
    # ELB SSL Cert:         wildcard.risingtidegames.com
    # EC2 Keyname:          rtg
    # EC2 Environment Name: dev
    # App Env (lowercase):  slots-dev-3
    # Env Name:             slots
    # Env Stage:            dev
    # Environment Version:  3
    # SQS Env ARN:          Slots-Dev
    # EC2 Instance Type:    m4.large
    # AWS Account:          480352787924
    # Service Role:         aws-elasticbeanstalk-service-role
    # Beanstalk App Name:   slots-dev
    exit (0)


