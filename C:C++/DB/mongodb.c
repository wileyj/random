//  gcc --std=c99 mongodb.c -lmongoc -o m_query

#define MONGO_HAVE_UNISTD

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include "mongo.h"

int main(int argc, char **argv) {
  int count = 100000;
  time_t rawtime;
  rawtime = time(NULL);
  printf("epoch: %ju\n", rawtime);
  char name[80] = "centos";
  int n;
  mongo conn[1];
  int status = mongo_client( conn, "172.17.148.149", 27017 );
    if( status != MONGO_OK ) {
      switch ( conn->err ) {
        case MONGO_CONN_NO_SOCKET:
          printf( "no socket\n" );
          return 1;
        case MONGO_CONN_FAIL:
          printf( "connection failed\n" );
          return 1;
        case MONGO_CONN_NOT_MASTER:
          printf( "not master\n" );
          return 1;
      }
    }
  }
  return ;
}
