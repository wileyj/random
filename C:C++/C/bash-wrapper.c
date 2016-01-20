#include <libgen.h>
#include <unistd.h>
#include <stdio.h>
#include <time.h>
#include <string.h>
#include <stdlib.h>


#define MYEXECNAME "perl"
#define PERLTOEXECUTE "/usr/bin/perl.real"
#define DEBUUG 0

int main (int argc, char *argv[]) {

int i=0;
char mytime[128];
time_t rawtime;
struct tm * timeinfo;
char *myname;
char *mybasename;    
char *argname_d;
char *argname_p;
char *argpathname;
char *argbasename;
char *bad1="/tmp";
char *bad2="/dev/shm";
char *logfilename="/var/log/perl.log";
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
                          
mybasename = basename(myname);

#ifdef DEBUG
printf("basename: %s\n", mybasename );
#endif


logfile = fopen(logfilename,"a");
if ( logfile == NULL) {
 printf("could not open logfile %s for writing\n",logfile);
 exit(-1);

}

 if ( strcmp (mybasename, MYEXECNAME ) == 0)
{

       #ifdef DEBUG
       printf("I was called as perl. ok, to continue\n");
       #endif
       
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
        argpathname = dirname(argname_d);
        argbasename = basename(argname_p); 
#ifdef DEBUG
        printf("%s %s %s\n", argv[i], argpathname, argbasename);
#endif
        if ( strcmp( argpathname, bad1) == 0 || strcmp( argpathname, bad2) == 0 ) {
         fprintf(logfile,"%s FATAL: Not executing from %s -> %s\n",mytime, argpathname, argv[i]);
         exit(-1);
        }
        else {
         fprintf(logfile, "%s Executing -> %s\n",mytime, argv[i]);
        }
        free(argname_d);
        free(argname_p);

       }
       fclose(logfile);
       execv(PERLTOEXECUTE,argv);
       
}
else {
       printf("I was called as a different program as expected: %s, terminating\n", mybasename);
       exit(-1);
}


}
