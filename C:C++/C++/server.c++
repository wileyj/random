#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h> 
#include <sys/socket.h>
#include <netinet/in.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <sqlite3.h>
#include <iomanip>
#include "split.h"

using namespace::std;
char rsync_p[15]    = "/usr/bin/rsync";
sqlite3 *db;
char *zErrMsg = 0;
int  cc2;
char *sql;
char *table_insert;
char *table_query;
char *table_update;
char *comma = ",";
char *paren = ")";
char *single_q = "'";
std::string type;
std::string colHost;
std::string colStart;
std::string colStop;
std::string colStatus;
const char* db_name = "rsync_server.db";

char *table_verify = "SELECT name FROM sqlite_master WHERE type IN ('table','view') AND name LIKE 'SYNC' UNION ALL  SELECT name FROM sqlite_temp_master WHERE type IN ('table','view')";
char *table_create = "CREATE TABLE SYNC(HOST TEXT PRIMARY KEY NOT NULL, START CHAR(20), STOP CHAR(20), STATUS CHAR(10) NOT NULL)";
char *table_show   = "SELECT * FROM SYNC";
//char *table_delete = "DELETE from SYNC where HOST=<host>";
char t_insert[255] = "INSERT INTO SYNC (HOST,START,STOP,STATUS) VALUES ('";
char t_query[255]  = "Select * from SYNC where host='";
char t_update[255] = "UPDATE SYNC SET stop='";

int sql_query(char *sql_stmt, std::string type);
int runps(char* process);
void parse_client(int);
int sql_q(int argc, char *host, char *start, char *stop, char *status);
char *rsync_argv[] = {"/etc/init.d/rsyncd", "restart", 0};

struct Config {
    int server_port;
    int rsync_port;    
    std::string cq_user;       
    std::string cq_pass;       
    std::string snapshot_size; 
    int start_time;    
    int end_time;      
};

static int callback(void *NotUsed, int argc, char **argv, char **azColName){
  if (type.compare("show") == 0){
    int i;
    for(i=0; i<argc; i++){
      if (strcmp(azColName[i], "HOST")==0){
        colHost = argv[i];
      }
      if (strcmp(azColName[i], "START")==0){
        colStart = argv[i];
      }
      if (strcmp(azColName[i], "STOP")==0){
        colStop = argv[i];
      }
      if (strcmp(azColName[i], "STATUS")==0){
        colStatus = argv[i];
      }
    }
    cout<<setw(40)<<left<<colHost<<"| "<<setw(27)<<left<<colStart<<"| "<<setw(27)<<left<<colStop<<"| "<<setw(19)<<left<<colStatus<<std::endl;
    cout<<"-------------------------------------------------------------------------------------------------------------"<<std::endl;
  }
  return 0;
}

void loadConfig(Config& config) {
    ifstream fin("config.properties");
    string line;
    while (getline(fin, line)) {
        istringstream sin(line.substr(line.find("=") + 1));
        if (line.find("server_port") == 0){
            sin >> config.server_port;
        }else if (line.find("rsync_port") == 0){
            sin >> config.rsync_port;
        }else if (line.find("cq_user") == 0){
            sin >> config.cq_user;
        }else if (line.find("cq_pass") == 0){
            sin >> config.cq_pass;
        }else if (line.find("snapshot_size") == 0){
            sin >> config.snapshot_size;
        }else if (line.find("start_time") == 0){
            sin >> config.start_time;
        }else if (line.find("end_time") == 0){
            sin >> config.end_time;
        }
    }
}

void error(const char *msg){
    perror(msg);
    exit(1);
}
int db_op(std::string op){
  sqlite3 *db;
  int  rc;
  const char* db_name = "rsync_server.db";
  rc = sqlite3_open(db_name, &db);
  if(op.compare("open") == 0){
    if( rc ){
      cout<<"Can't open database: "<<db_name<<" "<<sqlite3_errmsg(db)<<std::endl;
      return 1;
    }else{
      cout<<"Opened database successfully"<<std::endl;
    }
  }
  if (sql_query(table_verify, "verify") != 0){
    cout<<"Table Sync does not exist. Creating"<<std::endl;
    cout<<"table_create:" <<table_create<<std::endl;
    if(sql_query(table_create, "create") != 0){
      cout<<"Error Creating the SYNC table. exiting"<<std::endl;
      return 2;
    }else{
      cout<<"Table SYNC was successfully created"<<std::endl;
    } 
  }else{
      cout<<"Table SYNC already exists"<<std::endl;
  }
  if (op.compare("close") == 0){
    sqlite3_close(db);
  }
  return 0;
}

int main(int argc, char *argv[]){
  db_op("open");
  Config config;
  loadConfig(config);
  int s_port = config.server_port;
  if (runps(rsync_p) == 0){
    cout<<"rsync is running: "<<runps(rsync_p)<<std::endl;
    //testRsync(config.rsync_port);    
  }else{
    cout<<"Starting rsync"<<std::endl;
    int pid_ps = fork();
    if (pid_ps == 0) {
      execv("/etc/init.d/rsyncd", rsync_argv);
    }
  }
  int sockfd, newsockfd, portno, clilen, pid;
  struct sockaddr_in serv_addr, cli_addr;
  sockfd = socket(AF_INET, SOCK_STREAM, 0);
  if (sockfd < 0){ 
     error("ERROR opening socket");
  }
  bzero((char *) &serv_addr, sizeof(serv_addr));
  portno = s_port;
  serv_addr.sin_family = AF_INET;
  serv_addr.sin_addr.s_addr = INADDR_ANY;
  serv_addr.sin_port = htons(portno);
  if (bind(sockfd, (struct sockaddr *) &serv_addr, sizeof(serv_addr)) < 0){
    error("ERROR on binding");
  }
  listen(sockfd,5);
  clilen = sizeof(cli_addr);
  while(1){
    newsockfd = accept(sockfd, (struct sockaddr *)&cli_addr, (socklen_t*)&clilen);
    if (newsockfd < 0){
      error("ERROR on accept");
      pid = fork();
      if (pid < 0){
       error("ERROR on fork");
      }
      if (pid == 0)  {
        close(sockfd);
        parse_client(newsockfd);
        exit(0);
      }else{
        close(newsockfd);
      }
    }
  }
  db_op("close");
  return 0;
}
void parse_client(int sock){
  int n;
  char buffer[256];
  bzero(buffer,256);
  n = read(sock,buffer,255);
  if (n < 0){ 
    error("ERROR reading from socket");
  }else{
    Splitter received ( buffer, "|");
    char *r_host   = (char*)received[0].c_str();
    char *r_start  = (char*)received[1].c_str();
    char *r_stop   = (char*)received[2].c_str();
    char *r_status = (char*)received[3].c_str();
    int count = received.size();
    cout<<"Count: "<<count<<std::endl;
    if(sql_q(count, r_host, r_start, r_stop, r_status) == 0){
      cout<<"Received from client: "<<buffer<<std::endl;
      n = write(sock,"I got your message",18);
      if (n < 0){ 
        error("ERROR writing to socket");
      }
    }
  }
}
int sql_q(int argc, char *host, char *start, char *stop, char *status){
  if (argc == 1){
    if (sql_query(table_show, "show") != 0){
      cout<<"Error showing all data in SYNC table"<<std::endl;
    }
    return 0;
  }
  if (argc > 1){
    strcat(t_insert, host);
    strcat(t_insert, single_q);
    strcat(t_insert, comma);
    strcat(t_insert, single_q);
    strcat(t_insert, start);
    strcat(t_insert, single_q);
    strcat(t_insert, comma);
    strcat(t_insert, single_q);
    strcat(t_insert, stop);
    strcat(t_insert, single_q);
    strcat(t_insert, comma);
    strcat(t_insert, single_q);
    strcat(t_insert, status);
    strcat(t_insert, single_q);
    strcat(t_insert, paren);
    table_insert = t_insert;
    cout<<"table_insert: "<<table_insert<<std::endl;

    strcat(t_update, stop);
    strcat(t_update, single_q);
    strcat(t_update, comma);
    strcat(t_update, "STATUS='");
    strcat(t_update, status);
    strcat(t_update, single_q);
    strcat(t_update, "WHERE HOST='");
    strcat(t_update, host);
    strcat(t_update, single_q);
    table_update = t_update;
    cout<<"table_update: "<<table_update<<std::endl;

    strcat(t_query, host);
    strcat(t_query, single_q);
    table_query  = t_query;
    cout<<"table_query:  "<<table_query<<std::endl;
    cout<<"Running query"<<std::endl;
    cout<<"table_query: "<<table_query<<std::endl;
    if (sql_query(table_query, "query") != 0){
      if (sql_query(table_insert, "insert") != 0){
        cout<<"Error inserting data into SYNC"<<std::endl;
        cout<<"out: "<<table_insert<<std::endl;
      }
    }else{
      if(sql_query(table_update, "update") != 0){
        cout<<"Error Updating record for: "<<host<<std::endl;
      }else{
        cout<<"Update records for host: "<<host<<std::endl;
        sql_query(table_query, "query");
      }
    }
    if (type.compare("show") == 0){
      type = "show";
      cout<<"table_show :"<<table_show<<std::endl;
      if (sql_query(table_show, "show") != 0){
        cout<<"Error showing all data in SYNC table"<<std::endl;
      }
    }
  }
  return 0;
}
int sql_query(char *sql_stmt, std::string type){
  cout<<"Function: sql_query"<<std::endl;
  cout<<"Type: "<<type<<std::endl;
  cout<<"Sql_stmt: "<<sql_stmt<<std::endl;
  rc2 = sqlite3_exec(db, sql_stmt, callback, 0, &zErrMsg);
  if( rc2 != SQLITE_OK ){
    cout<<"SQL error: "<<zErrMsg<<std::endl;
    sqlite3_free(zErrMsg);
  }else{
    if (type.compare("show") == 0){
      cout<<std::endl;
      cout<<"-------------------------------------------------------------------------------------------------------------"<<std::endl;
      cout<<setw(40)<<left<<"Host"<<setw(29)<<left<<"| Start"<<setw(29)<<left<<"| Stop"<<setw(15)<<left<<"| Status"<<std::endl;
      cout<<"-------------------------------------------------------------------------------------------------------------"<<std::endl;
    }
    cout<<type<<" Query: "<<sql_stmt<<std::endl;
    cout<<"Returned Succeessfully"<<std::endl;
  }
  return 0;
}