#include <iostream>
#include <string>
#include "global.h"
using namespace std;

int addition(int a, int b){

  return((a+b)*2);
}
int subtraction(int a, int b){
  return ((a-b)*2);
}
int operation (int x, int y, int (*func_to_call)(int,int)){
  int g;
  g = (*func_to_call)(x,y);
  return (g);
}
int main(){
  int m,n;
  cout << "Enter first num:";
  cin >> m;
  cout << "Enter second num:";
  cin >> n;
  cout <<"firstnum:"<<m<<CR;
  cout <<"secondnum:"<<n<<CR;

  int (*minus)(int, int) = subtraction;
  m = operation(m,n,addition);
  n = operation(m,n,minus);

  cout<< CR<<"value of add:"<<m;
  cout<< CR<<"value of sub:"<<n;
  return 0;
}
