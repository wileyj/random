//  gcc --std=c99 mongodb-index.c -lmongoc -o m_index
#define MONGO_HAVE_UNISTD


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <libmongoc-1.0//mongo.h>
#include <unistd.h>

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
/*
  for (n = 0; n<count; n++){
    int g = rawtime+n;
    char ch[6];
    char name[12];
    strcpy(name, "centos");
    sprintf(ch, "%d", n);
    strcat(name, ch);
*/
    // index based on "name"
    bson key[1];
    bson_init( key );
    bson_append_int( key, "id", 1 );
    bson_append_int( key, "h", 1 );
    bson_append_int( key, "n", 1 );
    bson_append_int( key, "r", 1 );
    bson_append_int( key, "t", 1 );
    bson_finish( key );
    mongo_create_index( conn, "test.hosts", key, NULL, 0, NULL );
    bson_destroy( key );

  
    // index everything
/*
    bson_init( key );
    bson_append_int( key, "name", 1 );
    bson_append_int( key, "diskfree-/var", 1 );
    bson_append_int( key, "diskfree-/opt", 1 );
    bson_append_int( key, "check_nrpe", 1 );
    bson_append_int( key, "uptime", 1 );
    bson_append_int( key, "time", 1 );
    bson_finish( key );
    mongo_create_index( conn, "test.hosts", key, NULL, 0, NULL );
    bson_finish( key );
*/
  //}
  printf( "connection done\n");
  mongo_destroy( conn );
  return 0;
}
