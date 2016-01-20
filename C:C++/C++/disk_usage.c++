#include <sys/types.h>
#include <sys/statvfs.h>
#include <stdlib.h>
#include <stdio.h>

void main(){
    struct statvfs sbuf;

    if (statvfs("/", &sbuf) < 0)
        exit(-1);
    printf("Bytes left:%d\n",sbuf.f_bsize*sbuf.f_bavail);
}
