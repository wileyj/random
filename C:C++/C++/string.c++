#include <iostream>
#define CR '\n'
using namespace std;

int main(){
  cout << "Enter a string:";
  string myString;
  getline (cin, myString);
  cout << "\tentered: " << myString << CR;
  
  return 0;
}
