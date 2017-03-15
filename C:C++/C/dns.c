// gcc -pthread dns.c -o ddig
#include <sys/time.h>
#include <time.h>
#include <errno.h>
#include <err.h>
#include <signal.h>
#include <unistd.h>
#include <netdb.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NUM_THREADS     1
const char *progname = "ddig";
int timeout = 0; //defaults to system timeout of ~5 seconds
struct timeval start, end;
int msec;
float timed;
int done = 0;
int error = 0;
struct hostent *h;
char ipaddress[15];
char hostname[100];
char expected[15];
int use_expected = 0;
int use_timeout = 0;
int match;
int i;
int retries;
int foundHost;

void *DnsLookup(void *threadid){
    if ((h=gethostbyname(hostname)) == NULL) {
        done = 1;
        error = 1;
        pthread_exit(NULL);
    }else{
        strcpy(ipaddress, inet_ntoa(*((struct in_addr *)h->h_addr)));
        h=gethostbyname(hostname);
        done = 1;
        pthread_exit(NULL);
    }
}

int main (int argc, char *argv[]){
    gettimeofday(&start, NULL);
    pthread_t threads[NUM_THREADS];
    if (argc < 2 ){
        print_usage();
    }else{
        strcpy(hostname, argv[1]);
    }
    int rc, t;
    t = 1;
    rc = pthread_create(&threads[t], NULL, DnsLookup, (void *) NUM_THREADS);
    while (done == 0 ){
        if (use_timeout == 1){
            if (timeout <=  0){
                // CRITICAL FAILURE: timeout has been reached
                get_time();
                printf("CRITICAL Timeout reached on lookup for %s\n", hostname);
                exit(2);
            }
            timeout--;
            sleep(1);
        }
    }
    if (error == 1){
        // WARNING FAILURE: unknown host
        printf("DNS WARNING - nslookup returned error status for %s\n", hostname);
        exit(1);
    }else{
        printf ("%s", ipaddress);
    }
    if (rc){
        // PROGRAM ERROR
        get_time();
        printf("CRITICAL thread error: %d\n", rc);
        exit(2);
    }
    get_time();
    pthread_exit(NULL);
    exit(0);
}
get_time(void){
    gettimeofday(&end, NULL);
    msec = ((end.tv_sec * 1000000 + end.tv_usec) - (start.tv_sec * 1000000 + start.tv_usec)) / 100;
    timed = msec *.0001;
}
print_usage (void){
    printf (("\nUsage:  \n"));
    printf ("\t%s [host] \n\n", progname);
    exit (0);
}
