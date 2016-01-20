#include <openssl/rsa.h>
#include <openssl/pem.h>
#include <openssl/err.h>
#include <stdio.h>
#include <string.h>
#include "global.h"

using namespace::std;
void free_stuff();

//int rsa_decrypt(int encrypt_len, RSA *keypair){
int rsa_decrypt(RSA *keypair){
  rsa_d = (char*)malloc(encrypt_len);
  if(RSA_private_decrypt(encrypt_len, (unsigned char*)rsa_e, (unsigned char*)rsa_d, keypair, RSA_PKCS1_OAEP_PADDING) == -1) {
    ERR_load_crypto_strings();
    ERR_error_string(ERR_get_error(), err);
    fprintf(stderr, "Error decrypting message: %s\n", err);
    free_stuff();
    return 1;
  }
  printf("Decrypted message: %s\n", rsa_d);
  return 0;
}
