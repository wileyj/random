//  gcc redis.c -lhiredis -o r_insert
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <hiredis.h>

int main(int argc, char **argv) {
  redisReply *reply;
  long int i;
  redisContext *c = redisConnect("localhost", 6379);
  if (c->err) {
    printf("Error: %s\n", c->errstr);
  }else{
    printf("Connection Made! \n");
  }

  int count = 100000;
  time_t rawtime;
  rawtime = time(NULL);
  printf("epoch: %ju\n", rawtime);
  char name[80] = "centos";
  int n;
  for (n = 0; n<count; n++){
    int g = rawtime+n;
    char ch[6];
    char name[12];
    strcpy(name, "centos");
    sprintf(ch, "%d", n);
    strcat(name, ch);
    //printf("Adding key-values for item %i\n", n);
    reply = (redisReply *) redisCommand(c, "hset %s name %s",          name, name);
    reply = (redisReply *) redisCommand(c, "hset %s diskfree-/var %s", name, "90%");
    reply = (redisReply *) redisCommand(c, "hset %s diskfree-/opt %s", name, "75%");
    reply = (redisReply *) redisCommand(c, "hset %s check_nrpe %s",    name, "OK");
    reply = (redisReply *) redisCommand(c, "hset %s uptime %s",        name, "100 Days");
    reply = (redisReply *) redisCommand(c, "hset %s time %i",          name, g);
  }
  /* Disconnects and frees the context */
  redisFree(c);
  return 0;
}
