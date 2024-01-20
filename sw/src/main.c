#include <stdint.h>
#include "kuzn.h"

int main(int argc, char const *argv[])
{
	uint32_t data_for_encryption[DSIZE] = {0x99c72ae4, 0xac17b4fe, 0x9a41c389, 0x3ee5c99f};
	uint32_t encrypted_data[DSIZE];

	kuzn_init();
	kuzn_encrypt_data(data_for_encryption, encrypted_data);

	while(1){}

	return 0;
}