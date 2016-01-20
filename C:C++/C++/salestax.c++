#include <iostream>
#define CR '\n'
using namespace std;

float beforeTax(float a,float b){
  float r;
  r=(a*b);
  return r;
}
float afterTax(float a, float b){
  float r;
  r=(a*b)+((r)*.07);
  return r;
}
float totalTax(float a, float b){
  float r;
  r=((a*b)*.07);
  return r;
}

int main(){
  float a;
  float b;
  cout << "Enter price of item: ";
  cin >> a;
  cout << "Enter Number of items: ";
  cin >> b;
 
  float beforetax = beforeTax(a,b);
  float aftertax = afterTax(a,b);
  float totaltax = totalTax(a,b);
  cout << "Total price (before tax): " << beforetax << CR;
  cout << "Total price (after tax): " << aftertax << CR;
  cout << "Total price of Tax: " << totaltax << CR;
}
