/*
g++ -I/usr/include/hiredis -L/usr/lib64 -L/lib64 -L/usr/lib -lmongoc -lhiredis insert-new.cpp
*/

#define MONGO_HAVE_UNISTD
#define CHECK(X) if ( !X || X->type == REDIS_REPLY_ERROR ) { printf("Error\n"); exit(-1); }

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <iostream>
#include <sstream>
#include <fstream>
#include <unistd.h>
#include <vector>
#include <sys/types.h>
#include <sys/stat.h>
#include <hiredis.h>
#include <mongo.h>
#include <sys/time.h>
#include "split.h"

using namespace::std;

void read_template(mongo *conn, redisContext *rconn, std::string host);
const char *db = "test.hash";
std::vector<std::string> m_keys;
std::vector<std::string> m_vals;

const std::string currentDateTime() {
  time_t     now = time(0);
  struct tm  tstruct;
  char       buf[80];
  tstruct = *localtime(&now);
  strftime(buf, sizeof(buf), "%Y-%m-%d.%X", &tstruct);
  return buf;
}

int main(int argc, char **argv) {
  mongo conn[1];
  time_t rawtime;
  rawtime = time(0);
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
  
  redisContext *rconn;
  rconn = redisConnect("localhost", 6379);
  if (rconn->err) {
    printf("Error: %s\n", rconn->errstr);
  }else{
    printf("Connection Made! \n");
    redisReply *reply;
    reply = (redisReply *) redisCommand(rconn, "flushall", NULL, NULL);

  }

  char *filename;
  filename = "hostlist";
  ifstream inputfile;
  //cout<<"Reading file: "<<filename<<std::endl;
  inputfile.open(filename, ios::in);
  string myStr;
  while(!inputfile.eof()){
    string line;
    getline(inputfile,line);
     if(!line.empty()){
       read_template(conn, rconn, line);
    }
  }
  printf( "connection done\n");
  mongo_destroy( conn );
  redisFree(rconn);
  return 0;
}
void read_template(mongo *conn, redisContext *rconn, std::string host){
  char *filename2;
  filename2 = "check-template";
  ifstream inputfile2;
  //cout<<"Reading File ("<<filename2<<") for host: "<<host<<std::endl;
  inputfile2.open(filename2, ios::in);
  string myStr2;
  redisReply *reply;
  const char *c_host    = host.c_str();
  m_keys.clear();
  m_vals.clear();
  //m_keys.push_back("host");
  //m_vals.push_back(c_host);

  redisAppendCommand(rconn, "sadd hosts %s", c_host);
  while(!inputfile2.eof()){
    string line2;
    getline(inputfile2,line2);
    if(!line2.empty()){
      Splitter split ( line2, "|");
      time_t rawtime = time(0);
      std::stringstream ss;
      ss << rawtime;
      std::string epoch   = ss.str();
      std::string field   = split[0];
      std::string rc      = split[1];
      std::string message = split[3];
      std::string value     = host + "|" + field + "|" + message + "|" + rc + "|" + epoch;
      const char *c_value   = value.c_str();
      const char *c_host    = host.c_str();
      const char *c_field   = field.c_str();
      const char *c_rc      = rc.c_str();
      const char *c_epoch   = epoch.c_str();
      const char *c_message = message.c_str();
      redisAppendCommand(rconn, "hset %s %s %s", c_host, c_field, c_value);
      	m_keys.push_back(c_field);
	m_vals.push_back(c_message);
	m_keys.push_back("return");
	m_vals.push_back(rc);
	m_keys.push_back("timestamp");
	m_vals.push_back(c_epoch);

    }
  }
  int keysize = m_keys.size();
  int valsize = m_vals.size();
  time_t rawtime;
  rawtime = time(0);

  cout<<"Adding items to DB for: "<<host<<std::endl;
  bson b;
  bson_init(&b);
  bson_append_string(&b, "host", c_host);
  bson_append_int(&b, "time", rawtime);
  bson_append_start_array(&b, "items");
  for (int i=0; i<keysize; i++){
    const char *ch_key  = m_keys[i].c_str();
    const char *ch_val  = m_vals[i].c_str();
    i++;
    const char *rc_key  = m_keys[i].c_str();
    const char *rc_val  = m_vals[i].c_str();
    i++;
    const char *time_key = m_keys[i].c_str();
    const char *time_val = m_vals[i].c_str();

    bson_append_start_object(&b, ch_key);
      bson_append_string(&b, "n", ch_key);   // name
      bson_append_string(&b, "v", ch_val);   // value
      bson_append_string(&b, "r", rc_val);   // return code
      bson_append_string(&b, "t", time_val); // timestamp
    bson_append_finish_object(&b);
  }
  bson_append_finish_object( &b );
  bson_append_finish_object( &b );
  bson_finish( &b );
  mongo_insert( conn, db, &b, 0 );
  bson_destroy( &b );
/*
    bson_init( &b );
    bson_append_new_oid( &b, "_id" );
    bson_append_new_oid( &b, "user_id" );
    bson_append_start_array( &b, "items" );
      bson_append_start_object( &b, "0" );
        bson_append_string( &b, "name", "John Coltrane: Impressions" );
        bson_append_int( &b, "price", 1099 );
      bson_append_finish_object( &b );

      bson_append_start_object( &b, "1" );
        bson_append_string( &b, "name", "Larry Young: Unity" );
        bson_append_int( &b, "price", 1199 );
      bson_append_finish_object( &b );
    bson_append_finish_object( &b );
    bson_finish( &b );
*/

  int getreply = redisGetReply(rconn, (void **) &reply );
  if ( getreply == REDIS_ERR ) { 
    printf("Error\n"); exit(-1); 
  }
  CHECK(reply);        
  freeReplyObject(reply);
}
