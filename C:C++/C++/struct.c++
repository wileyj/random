#include <iostream>
#include <string>
#include <sstream>
#include "global.h"
using namespace std;

struct car{
  int year;
  string name;
} mine, yours;

int main(){
  string mystr;
  mine.year=1999;
  mine.name="Jeep Grand Cherokee";

  cout << "Enter car name:";
  getline (cin,yours.name);
  cout << "Enter car year:";
  getline(cin, mystr);
  stringstream(mystr) >> yours.year;

  cout<< "Mine:";
  cout << "\tname:"<<mine.name<<CR;
  cout << "\tyear:"<<mine.year<<CR;
  
  cout<<CR<<"Yours:";
  cout << "\tname:"<<yours.name<<CR;
  cout << "\tyear:"<<yours.year<<CR;
  
return 0;
}
