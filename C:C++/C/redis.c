    //gcc redis.c -lhiredis -lssl && ./a.out

    #define MAX_BUF_LEN  (128)
    #define REDIS_PORT (6379)
    #define REDIS_HOST ("localhost")
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <time.h>
    #include <hiredis/hiredis.h>
    #include <openssl/sha.h>

    int main (int argc, char *argv){
        srand (time(NULL));
        redisReply *reply;
        long int i;
        redisContext *c = redisConnect(REDIS_HOST,REDIS_PORT);

        if (c->err){
            printf("Error connecting to redis DB on %s on port %i\n", "localhost", REDIS_PORT);
        }else{
            printf("Connected to redis on port %s on host %i\n", "localhost", REDIS_PORT);
        }

        int n;
        int count = 100;
        for (n = 0; n<count; n++){
            int o1        = rand() % 180 + 1;
            int o2        = rand() % 150 + 1;
            int o3        = rand() % 254 + 1;
            int o4        = rand() % 254 + 1;
            int vgsize    = rand() % 25  + 8;
            int m1        = rand() % 2 + 5;
            int m2        = rand() % 3 + 2;
            int mem       = rand() % 2038 + 1024;

            unsigned char buf[MAX_BUF_LEN];
            int y=0;
            SHA_CTX sc;
            unsigned char hash[SHA_DIGEST_LENGTH];
            SHA1_Init(&sc);
            SHA1_Update(&sc, buf, o3);
            SHA1_Final(hash,&sc);
            char serial[SHA_DIGEST_LENGTH*2];
            while ( y<SHA_DIGEST_LENGTH) {
                sprintf((char*)&(serial[y*2]), "%02x", (unsigned int)hash[y]);
                y++;
            }
            char octet1[3];
            char octet2[3];
            char octet3[3];
            char octet4[3];
            char os_version[3];
            char os_major[1];
            char os_minor[1];

            //sprintf(os_minor, "%i", m2);
	    //sprintf(os_major, "%i", m1);


            printf("\n");
            printf("MAJOR_V: %i\n", m1);
	    sprintf(os_major, "%i", m1);
            printf("MINOR_V: %i\n", m2);

            sprintf(os_minor, "%i", m2);
            printf("OS_MAJOR: %s\n", os_major);
            printf("OS_MINOR: %s\n", os_minor);

            printf("MINOR_VC: %s\n", os_minor);
           
            strcpy(os_version, os_major);
            strcat(os_version, ".");
            strcat(os_version, os_minor);
            
	    sprintf(octet1,"%i",o1);
            sprintf(octet2,"%i",o2);
            sprintf(octet3,"%i",o3);
            sprintf(octet4,"%i",o4);

            char ip[15];
            strcpy(ip,octet1);
            strcat(ip,".");
            strcat(ip,octet2);
            strcat(ip,".");
            strcat(ip,octet3);
            strcat(ip,".");
            strcat(ip,octet4);


            printf("serial: %s\n", serial);
            printf("IP: %i.%i.%i.%i\n", o1,o2,o3,o4);
            printf("IPADDRESS: %s\n",ip);
            printf("VGSIZE: %i\n", vgsize);
            printf("osversion: %s\n", os_version);
            printf("Mem: %i\n", mem);

            time_t epoch      = time(NULL);
            char name[80]     = "centos-vm-";
            char *desc        = "test host vm 1";
            char *location      = "VirtualBox VM on laptop";
            char *partition     = "default";
            char *os        = "Centos";
            //char *os_vers     = "6.5";
            char *app_server    = "";
            char *app_server_vers = "";
            char *status      = "development";
            char *notes       = "";
            char *instance      = "1.rhm.com";
            char *cpu       = "1";
            char *memory      = "1877";
            char *vg_size     = "15.61";

            if (n < 100){
                strcat(name, "0");
            }else if (n < 10 ){
                strcat(name, "00");
            }else{
                strcat(name, "");
            }
            char ch1[3];
            sprintf(ch1, "%d", n);
            strcat(name, ch1);
        
            reply = (redisReply *) redisCommand(c, "hset %s name %s", name, name);
            reply = (redisReply *) redisCommand(c, "hset %s ip %s", name, ip);
            reply = (redisReply *) redisCommand(c, "hset %s desc %s", name, desc);
            reply = (redisReply *) redisCommand(c, "hset %s location %s", name, location);
            reply = (redisReply *) redisCommand(c, "hset %s serial %s", name, serial);
            reply = (redisReply *) redisCommand(c, "hset %s partition %s",  name, partition);
            reply = (redisReply *) redisCommand(c, "hset %s os %s", name, os);
            reply = (redisReply *) redisCommand(c, "hset %s os_vers %s",  name, os_version);
            reply = (redisReply *) redisCommand(c, "hset %s app_server %s", name, app_server);
            reply = (redisReply *) redisCommand(c, "hset %s app_server_vers%s", name, app_server_vers);
            reply = (redisReply *) redisCommand(c, "hset %s status %s", name, status);
            reply = (redisReply *) redisCommand(c, "hset %s notes %s",  name, notes);
            reply = (redisReply *) redisCommand(c, "hset %s instance %s", name, instance);
            reply = (redisReply *) redisCommand(c, "hset %s cpu %s",  name, cpu);
            reply = (redisReply *) redisCommand(c, "hset %s memory %s", name, memory);
            reply = (redisReply *) redisCommand(c, "hset %s vg_size %s",  name, vg_size);
    }

}
