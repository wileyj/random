//  gcc --std=c99 mongodb-insert.c -lmongoc -o m_insert
#define MONGO_HAVE_UNISTD


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <libmongoc-1.0/mongo.h>

int main(int argc, char **argv) {
  int count = 100000;
  time_t rawtime;
  rawtime = time(NULL);
  printf("epoch: %ju\n", rawtime);
  char name[80] = "centos";
  int n;
  mongo conn[1];
  int status = mongo_client( conn, "isg-mongo-001.1515.mtvi.com", 27017 );
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

  for (n = 0; n<count; n++){
    int g = rawtime+n;
    char ch[6];
    char name[12];
    strcpy(name, "centos");
    sprintf(ch, "%d", n);
    strcat(name, ch);
    bson b[1];
    bson_init( b );
    bson_append_string( b, "name", name );
    bson_append_string( b, "diskfree-/var", "90%" );
    bson_append_string( b, "diskfree-/opt", "70%" );
    bson_append_string( b, "check_nrpe", "OK" );
    bson_append_string( b, "uptime", "100 Days" );
    bson_append_int   ( b, "time", g );
    bson_finish( b );
    mongo_insert( conn, "test2.hosts", b, 0 );
    bson_destroy( b );
  }
  printf( "connection done\n");
  mongo_destroy( conn );
  return 0;
}
