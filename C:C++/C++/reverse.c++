#include <iostream>
#include <string>
#include "global.h"

using namespace std;

string reversed(string a){ 
  string output;
  reverse(a.begin(), a.end());
  output = a;
  return output;
}
int main(){
  cout << "Enter 4 different letters:";
  cin >> myString;
  for (int i=0;i< (int)myString.size();++i){
    while(!isalpha(myString[i])){
      cout << "found number ( "<<myString[i] << " ), enter 4 letters again:";
      cin >> myString;
    }
 } 

  stringSize = myString.size();
  cout << "string size: " << stringSize << CR;
  if (stringSize > 4){
    cout << "Only 4 chars are allowed. you entered: "<<stringSize<<CR;
    return 1;
  }else{
    cout << "Time to reverse the string" << CR;
    string theString = reversed(myString);
    cout << "theString: "<< theString << CR;
    return 0;
  }
}
