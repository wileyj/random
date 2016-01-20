#include <iostream>
#define CR '\n'
using namespace std;

int addition(int a, int b){
  int r;
  r=a+b;
  return r;
}
int subtraction(int a, int b){
  int r;
  r=a-b;
  return r;
}
int multiply(int a, int b){
  int r;
  r=a*b;
  return r;
}

float divide(float a, float b){
  float r;
  r=a/b;
  return r;
}

int main(){
  char a1;
  char b1;
  cout << "Enter number 1: ";
  if (cin >> a1 && !isdigit(a1)){
    while (!(isdigit(a1))){
      cout << "Not a Number - Enter number 1 again:";
      cin >> a1;
    }
  }
  cout << "Enter number 2: ";
  if (cin >> b1 && !isdigit(b1)){
    while (!(isdigit(b1))){
      cout << "Not a Number - Enter number 2 again:";
      cin >> b1;
    }
  }

  int add = addition(a1,b1);
  cout << "Add result: " << add << CR;
  int sub = subtraction(a1,b1);
  cout << "Subtraction result (" << a1 << "-" << b1 << "): " << sub << CR;
  int mul = multiply(a1,b1);
  cout << "Multiply result: " << mul << CR;
  float mod = divide(a1,b1);
  cout << "Divide result: " << mod<< CR;

}
