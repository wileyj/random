#include <string>
#include <iostream>
#include "global.h"
#include <sstream>
using namespace std;

const int NO_OF_ELEMENTS = 10;
typedef int numArray[NO_OF_ELEMENTS];

float average(numArray avg){
  float total=0;
  int count;
  for (count=0; count < NO_OF_ELEMENTS; count++){
    total +=float(avg[count]);
  }
return (total/NO_OF_ELEMENTS);
}
int main(){
  int numArray[NO_OF_ELEMENTS];
  numArray[0]=27;
  numArray[1]=33;
  numArray[2]=58;
  numArray[3]=74;
  numArray[4]=97;
  numArray[5]=90;
  numArray[6]=44;
  numArray[7]=65;
  numArray[8]=13;
  numArray[9]=85;
  string val2[3] = {"val1","val2","val3"};
  cout << "val of int numArray[3]: "<<numArray[3]<<CR;
  cout << "val of string val2[1]: "<<val2[1]<<CR;
  cout << "Average of array numArray:"<<average(numArray)<<CR;
  cout << "Array Values:"<<CR;
  for (int i=0;i<NO_OF_ELEMENTS;++i){
    cout << numArray[i]<<CR;
  }
  cout <<CR<<"Sorted Array:"<<CR;


  /*
  string input;
  cout << "enter new value for val2[0]:";
  cin >> input;
  cout << "Old value: "<<val2[0]<<CR;
  val2[1] = input;
  cout << "New value: "<<val2[0]<<CR;
  */
  cout << CR<<CR;


//loop through array
  const int MAX = 10;
  string newArray[10];
  for (int i=0;i<MAX;++i){
    stringstream ss;
    ss << i;
    newArray[i] = "item"+ss.str()+": "+ss.str();
  }
  for (int j=0;j<MAX;++j){
    cout <<"newArray val"<<j<<": "<<newArray[j]<<CR;
  }


  return 0;
}
