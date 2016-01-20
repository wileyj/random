#include <iostream>
#include <string>
#include <fstream>
#include <sstream>
#include "global.h"

int main(){
  string myFile="files/files1.txt";
  ofstream out_stream;
  ifstream if_stream;
  //out_stream.open("files/files1.txt", ios::app);
  out_stream.open(myFile.c_str());
  if (out_stream.fail()){
    cout << "Error opening Output file:"<<myFile.c_str()<<CR;
    exit(1);
  } 
  for (int i=0;i<100;++i){
    //cout << i<<") this is line:"<<i+1<<CR;
    out_stream << i<<") this is line:"<<i+1<<CR<<"\n";
  }
  out_stream.close();


  if_stream.open(myFile.c_str());
  if (if_stream.fail()){
    cout << "Error opening Input file:"<<myFile.c_str()<<CR;
    exit(1);
  }
  char character;
  string myStr;
  while(!if_stream.eof()){
    if_stream.get(character);
    if(character != '\n'){
      cout << character;
    }else{
      cout << endl;
    }
  }
  if_stream.close();
  
  return 0;
}
