#include <iostream>
#include "global.h"
using namespace std;

const int ITEMS=5;
int array[ITEMS];
void display_state(int a[], int stage, int length);
void swap(int& first, int& second);
int minimum_from(int a[], int position, int length);
void selection_sort(int a[], int length);

int main(){
  array[0]=113;
  array[1]=344;
  array[2]=985;
  array[3]=1194;
  array[4]=63;
  
  cout << "Current array:"<<CR;
  for(int i=0;i<ITEMS;++i){
    cout << "item:" << array[i] <<CR;
  }
  //sort array
selection_sort(array,ITEMS); 
cout << CR<<CR;
  for(int i=0;i<ITEMS;++i){
    cout << "item:" << array[i] <<CR;
  }



  return 0;
}
void selection_sort(int a[], int length){
  for (int count = 0 ; count < length - 1 ; count++){
    swap(a[count],a[minimum_from(a,count,length)]);
    //display_state(a,count,length);
  }
}
int minimum_from(int a[], int position, int length){
  int min_index = position;
  for (int count = position + 1 ; count < length ; count ++)
    if (a[count] < a[min_index])
    min_index = count;
  return min_index;
}
void swap(int& first, int& second){
  int temp = first;
  first = second;
  second = temp;
}
void display_state(int a[], int stage, int length){
  cout << "STATE " << stage + 2 << CR<<CR;
  for (int count = 0 ; count < length ; count++)
    cout << "element " << count << " = " << a[count] << CR;
    cout <<  CR;
}
