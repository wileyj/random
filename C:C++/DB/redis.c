//  gcc redis.c -lhiredis -o r_query
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <hiredis.h>
#include <iostream>
#include <sstream>
#include <fstream>
#include <unistd.h>
#include <vector>
#include <sys/types.h>
#include <sys/stat.h>
#include "split.h"



using namespace::std;

int query(redisContext *c, std::string host);

int main(int argc, char **argv) {
  redisContext *rconn;
  rconn = redisConnect("localhost", 6379);
  if (rconn->err) {
    printf("Error: %s\n", rconn->errstr);
  }else{
    printf("Connection Made! \n");
  }
  time_t rawtime;
  rawtime = time(NULL);
  printf("epoch: %ju\n", rawtime);
  char *filename;
  filename = "hostlist";
  ifstream inputfile;
  cout<<"Reading file: "<<filename<<std::endl;
  inputfile.open(filename, ios::in);
  string myStr;
  redisReply *reply;
  
  while(!inputfile.eof()){
    string line;
    getline(inputfile,line);
     if(!line.empty()){
       query(rconn, line);
    }
  }
  redisFree(rconn);
  return 0;
}
int query(redisContext *rconn, std::string host){
  //cout<<"Insert Hostname: "<<host<<std::endl;
  //cout<<"Getting key-values for: "<<host<<std::endl;
  //cout<<"hgetall "<<host.c_str()<<std::endl;
  redisReply *reply;
  reply = (redisReply *) redisCommand(rconn, "hgetall %s", host.c_str());
  //cout<<"elements: "<<reply->elements<<std::endl;
  for (int j = 0; j < reply->elements; j++) {
//    printf("%u) %s\n", j, reply->element[j]->str);
  }
  freeReplyObject(reply);
  return 0;
}
