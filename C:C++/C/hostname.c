#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <netdb.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

int main(int argc, char *argv[])
{
    struct hostent *h;
    char ipaddress[15];
    char hostname[100];
    if (argc != 2){
      printf("Usage: ./hostname <Server-Name>\n");
    }else{
      if ((h=gethostbyname(argv[1])) == NULL) {  // get the host info
        printf("Unknown Host: %s\n", argv[1]);
        exit(1);
      }else{
        strcpy(hostname, argv[1]);
        h=gethostbyname(hostname);
        strcpy(ipaddress, inet_ntoa(*((struct in_addr *)h->h_addr)));
        printf("\n");
        printf("ipaddress: %s\n", ipaddress);
        printf("hostname: %s\n", hostname);
        printf("\n");
        return(0);
      }
    }
}
/*
      strcpy(hostname, argv[1]);
      h=gethostbyname(hostname);
printf("hostname: %s\n", hostname);
      strcpy(ipaddress, inet_ntoa(*((struct in_addr *)h->h_addr)));
printf("ipaddress: %d\n", ipaddress);
      printf("hostname: %s\n", hostname);
      printf("name: %s\n", hostname);
      printf("ip: %s\n", ipaddress);
      return(1);
    }else{
      printf("Usage: ./hostname <server-name>\n");
      return (1);
    }
} 
*/
