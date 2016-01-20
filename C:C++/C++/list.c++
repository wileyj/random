#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include <errno.h>
#include <vector>
#include <string>
#include <iostream>

using namespace std;
struct stat st;
char *path;

int getdir (string dir, vector<string> &files){
  DIR *dp;
  struct dirent *dirp;
  if((dp  = opendir(dir.c_str())) == NULL) {
    cout << "Error(" << errno << ") opening " << dir << endl;
    return errno;
  }
  while ((dirp = readdir(dp)) != NULL) {
    stat(path, &st);
    if(st.st_mode & S_IFDIR){
      getdir(dir,files);
    }else{    
      files.push_back(string(dirp->d_name));
    }
  }
  closedir(dp);
  return 0;
}

int main(int argc, char* argv[]){
  string myString;
  if (argv[1] != NULL){
    myString = argv[1];
  }else{
    cout<< "Enter dir:";
    cin>>myString;
  }
  //string dir = string(".");
  string dir = string(myString);
  vector<string> files = vector<string>();
  getdir(dir,files);
  for (unsigned int i = 0;i < files.size();i++) {
    if (files[i] == "." || files[i] == ".."){
      //cout <<"FOUND DOT FILE: "<<files[i]<<endl;
    }else{
      //cout << "rm -f "<<myString<<"/"<<files[i] << endl;
      cout << myString << "/" << files[i] << endl;  
    }
  }
  return 0;
}
