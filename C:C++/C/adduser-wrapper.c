#include <libgen.h>
#include <unistd.h>
#include <stdio.h>
#include <time.h>
#include <string.h>
#include <stdlib.h>


#define MYEXECNAME "adduser"
#define PERLTOEXECUTE "/usr/sbin/adduser.real"
#define DEBUG 1 

int main (int argc, char *argv[]) {
	int i=0;
	char mytime[128];
	time_t rawtime;
	struct tm * timeinfo;
	char *myname;
	char *mybasename;    
	char *argname_d;
	char *argname_p;
	char *logfilename="/var/log/adduser.log";
	FILE *logfile;
 
	time (&rawtime);
	timeinfo = localtime (&rawtime);
	strftime(mytime, 127, "%F %R",timeinfo);

	#ifdef DEBUG
	printf("Time: %s\n", mytime);
	printf("\ncmdline args count=%d", argc);
	printf("\nexe name=%s", argv[0]);
	#endif

	myname = strdup(argv[0]);
	if ( myname == NULL ) {
 		printf("cannot allocate memory for string duplication, exit\n");
 		exit(-1);
	}
                         
	logfile = fopen(logfilename,"a");
	if ( logfile == NULL) {
 		printf("could not open logfile %s for writing\n",logfile);
 		exit(-1);
	}

 	if ( strcmp (mybasename, MYEXECNAME ) == 0){
       		for ( i=1; i<argc; i++ ) {
        		if ( i > 32766 ) {
         			printf("number of arguments exceeded int size, terminating\n");
         			exit(-1);
        		}
        		argname_d = strdup(argv[i]);
        		if ( argname_d == NULL ) {
         			printf("cannot allocate memory for string duplication, exit\n");
         			exit(-1);
        		}
        		argname_p = strdup(argv[i]);
        		if ( argname_p == NULL ) {
         			printf("cannot allocate memory for string duplication, exit\n");
         			exit(-1);
        		}
        		fprintf(logfile, "%s Executing -> %s\n",mytime, argv[i]);
        		free(argname_d);
        		free(argname_p);
       		}
       		fclose(logfile);
       		//execv(PERLTOEXECUTE,argv);
	}
}
