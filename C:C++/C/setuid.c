#include <stdio.h>
#include <string.h>

int shelldo(char *c){
  FILE *F;
  F = popen(c,"w");
  return pclose(F);
  fflush(NULL);
};

int main(){
  char str[100];
  char run[150];

  if( argc == 2){
    strcpy(str, argv[1]);
    strcpy(run, "./doRsync ");
    strcat(run, str);
  }else if(argc > 2){
    printf("Only one argument allowed\n");
  }else{
    printf("One argument expected\n");
  }
  FILE *F;
  fflush(NULL);
  shelldo(run);
};
