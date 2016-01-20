#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <netdb.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define PORT 22// the port client will be connecting to 
#define DEST_IP "169.77.175.29"
#define MAXDATASIZE 100 // max number of bytes we can get at once 

int main(int argc, char *argv[])
{
    int                bread,
                       timeout = 1000,
                       ret;
timeout = 1000;
    int sockfd, numbytes;  
    struct sockaddr_in their_addr; // connector's address information 
    struct hostent *gethostbyname(const char *name); 

    if ((sockfd = socket(PF_INET, SOCK_STREAM, 0)) == -1) {
        perror("socket");
        exit(1);
    }
bread = setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, (char*)&timeout, sizeof(timeout));
    their_addr.sin_family = AF_INET;    // host byte order 
    their_addr.sin_port = htons(PORT);  // short, network byte order 
    their_addr.sin_addr.s_addr = inet_addr(DEST_IP);
    memset(their_addr.sin_zero, '\0', sizeof their_addr.sin_zero);
printf("attempting connection to port 22\n");
if(bread == SOCKET_ERROR) 
    {
        printf("setsockopt(SO_RCVTIMEO) failed:\n"
    } 
    if (connect(sockfd, (struct sockaddr *)&their_addr,
                                          sizeof their_addr) == -1) {
        perror("connect");
        exit(1);
    }

    printf("succes: port is open\n");

    close(sockfd);

    return 0;
} 
