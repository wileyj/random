#include <libgen.h>
#include <unistd.h>
#include <stdio.h>
#include <time.h>
#include <string.h>
#include <stdlib.h>
#include <map>
#include <stdlib.h>
#include <iostream>
#include <errno.h>
#include <getopt.h>
#include <fcntl.h>

using namespace::std;

#define MYEXECNAME "adduser"
#define PERLTOEXECUTE "/usr/sbin/adduser.real"
#define DEBUG 1 
//char *logfilename = "/var/log/adduser.log" ;

void chomp(const char *s);
int get_id();
int help();
char* euid = NULL;

struct globalArgs_t {
    char* base_dir;
    char* comment;
    char* home_dir;
    bool  defaults       = false;
    char* expiredate;
    char* inactive;
    char* gid;
    char* groups;
    bool  help           = false;
    char* skel;
    char* key;
    bool  no_log_init    = false;
    bool  create_home    = false;
    bool  no_create_home = false;
    bool  no_user_group  = false;
    bool  non_unique     = false;
    char* password;
    bool  system         = false;
    char* shell;
    char* uid;
    bool  user_group     = false;
    char* selinux_user;
    bool verbose         = false;
} globalArgs;

static const struct option long_options[] = {
    { "basedir",        no_argument, NULL, 'b' },
    { "comment",        no_argument, NULL, 'c' },
    { "home-dir",       no_argument, NULL, 'd' },
    { "defaults",       no_argument, NULL, 'D' },
    { "expiredate",     no_argument, NULL, 'e' },
    { "inactive",       no_argument, NULL, 'f' },
    { "gid",            no_argument, NULL, 'g' },
    { "groups",         no_argument, NULL, 'G' },
    { "help",           no_argument, NULL, 'h' },
    { "skel",           no_argument, NULL, 'k' },
    { "key",            no_argument, NULL, 'K' },
    { "no-log-init",    no_argument, NULL, 'l' },
    { "create-home",    no_argument, NULL, 'm' },
    { "no-create-home", no_argument, NULL, 'M' },
    { "no-user-group",  no_argument, NULL, 'N' },
    { "non-unique",     no_argument, NULL, 'o' },
    { "password",       no_argument, NULL, 'p' },
    { "system",         no_argument, NULL, 'r' },
    { "shell",          no_argument, NULL, 's' },
    { "uid",            no_argument, NULL, 'u' },
    { "user-group",     no_argument, NULL, 'U' },
    { "selinux-user",   no_argument, NULL, 'z' },
    { "verbose",        no_argument, NULL, 'z' },
    { NULL,             no_argument, NULL, 0   }
};

int main (int argc, char *argv[]) {
    int i=0;
    int c;
    char mytime[128];
    time_t rawtime;
    struct tm * timeinfo;
    //char *logfilename="/var/log/adduser.log";
    FILE *logfile;
    if (get_id() == 0){
        globalArgs.verbose ? cout<<"Returning id: "<<euid<<std::endl : cout<<"";
    }else{
        cout<<"Error retrieving the actual user id"<<std::endl<<std::endl;
        exit(EXIT_FAILURE);
    }
    if (argc < 2 || (strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0)){
        help();
        exit(EXIT_FAILURE);
    } 
    while(1){
        int option_index = 0;
        c = getopt_long (argc, argv, "i:n:H:t:v?", long_options, &option_index);
        if (c == -1){
            break;
            switch(c){
                case 'i' :
                    globalArgs.ip = optarg;
                    break;
                default:
                    help(argv[0]);
                    return 1;
                    break;
            }    
        }
    }
    //globalArgs.ip      ? cout << "globalArgs.ip:      " << globalArgs.ip << std::endl      : cout<<"" ;
    time (&rawtime);
    timeinfo = localtime (&rawtime);
    strftime(mytime, 127, "%F %R",timeinfo);

    #ifdef DEBUG
    printf("Time: %s\n", mytime);
    printf("\ncmdline args count=%d", argc);
    printf("\nexe name=%s", argv[0]);
    #endif
}


int get_id(){
    FILE *inpipe;
    char inbuf[1000];
    unsigned int i;
    int inchar;
    char *command = "who -m | awk {'print $1'}";
    inpipe = popen(command, "r");
    if (!inpipe) {
        cout<<"Error reading system() output"<<std::endl;
        exit(15);
    }
    for (i = 0; i < sizeof(inbuf) - 1; i++) {
        inchar = fgetc(inpipe);
        if (inchar == EOF) {
            break;
        }
        inbuf[i] = inchar;
    }
    inbuf[i] = 0;
    chomp(inbuf);
    cout<<"Number of chars read = "<<i<<std::endl; 
    cout<<"Buffer: <"<<inbuf<<">"<<std::endl;
    pclose(inpipe);
    chomp(inbuf);
    euid = inbuf;
    return 0;
}   

void chomp(const char *s){
    char *p;
    while (NULL != s && NULL != (p = strrchr(s, '\n'))){
        *p = '\0';
    }
}

std::string trim(std::string s){
    size_t endpos = s.find_last_not_of(" \t");
    if( string::npos != endpos ){
        s = s.substr( 0, endpos+1 );
    }
    return s;
}

int help(){
  cout << "usage:\n                      " << std::endl;
  cout << "\t-v - Enable verbose logging (-vvvv)         " << std::endl;
  cout << "\t-e - Send email of output (Not Implemented) " << std::endl;
  cout << "\t-s - Suppress all output                    " << std::endl;
  cout << "\t-h - Help message                           " << std::endl;
  cout << "\t-r - List of Response Codes                 " << std::endl;
  cout << "\t-d - Run as a Daemon                        " << std::endl;
  cout << std::endl<<std::endl;
  return 0;
}