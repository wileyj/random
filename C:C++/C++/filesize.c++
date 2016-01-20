#include <stdio.h>
#include <sys/stat.h>
#include <stdlib.h>
size_t filesize(char *);

size_t filesize(char *filename){
     struct stat st;
     size_t retval=0;
     if(stat(filename,&st) ){
	     printf("cannot stat %s\n",filename);
     }else{
	   retval=st.st_size;
     }
     return retval;
}

int main(int argc, char *argv[]){
    printf("%u\d",filesize("myfile.dat");
    return 0;
}
