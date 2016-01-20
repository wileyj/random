#include <iostream.h>
#include <string.h>
#include <stdlib.h>

string cr;

int RSHash(string cr){
   int b    = 378551; //Ramdom Ranges I've chosen (can be modified)
   int a    = 63689;
   int hash = 0;  //Output hash
   int i;  //Temp number that scrolls through the string array

   for(i = 0; i < cr.length(); i++) //Loop to convert each character
   {
      hash = hash * a + cr[i];  //Algorithm that hashs
      a    = a * b;
   }

   return (hash & 0x7FFFFFFF); //Returns the hashed string
}

int main(){
        string cr;

        cout<<"Enter string : "; //Inputs the string from the user
        cin>>cr;

        cout<<RSHash(cr); //Outputs the result in the console

        system("PAUSE");  //Pauses and exits
        return 0;
}
