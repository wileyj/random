#include <openssl/rsa.h>
#include <openssl/pem.h>
#include <openssl/err.h>
#include <stdio.h>
#include <string.h>
#include "global.h"

using namespace::std;
void free_stuff();

int rsa_encrypt(char *msg, RSA *keypair){
  rsa_e = (char*)malloc(RSA_size(keypair));
  encrypt_len = 0;
  err = (char*)malloc(130);
  if((encrypt_len = RSA_public_encrypt(strlen(msg), (unsigned char*)msg, (unsigned char*)rsa_e, keypair, RSA_PKCS1_OAEP_PADDING)) == -1) {
    ERR_load_crypto_strings();
    ERR_error_string(ERR_get_error(), err);
    fprintf(stderr, "Error encrypting message: %s\n", err);
    free_stuff();
    return 1;
  }
  #ifdef WRITE_TO_FILE
    FILE *out = fopen("out.bin", "w");
    fwrite(rsa_e, sizeof(*rsa_e),  RSA_size(keypair), out);
    fclose(out);
    printf("Encrypted message written to file.\n");
    free(rsa_e);
    rsa_e = NULL;

    // Read it back
    printf("Reading back encrypted message and attempting decryption...\n");
    rsa_e = (char*)malloc(RSA_size(keypair));
    out = fopen("out.bin", "r");
    fread(rsa_e, sizeof(*rsa_e), RSA_size(keypair), out);
    fclose(out);
  #endif
  return 0;
}
