/***********************************************************************************
 * Copyright (C) 2024 Kirill Turintsev <billiscreezo228@gmail.com>
 * See LICENSE file for licensing details.
 *
 * This file contains definition of functions for working with the encryption module
 *
 ***********************************************************************************/

#include <stdint.h>
#include "kuzn.h"

void kuzn_read (uint32_t *);
void kuzn_write(const uint32_t *);

struct kuzn_regs
{
	uint8_t rst_n;
	uint8_t req_ack;
	uint8_t valid;
	uint8_t busy;
	uint32_t din[DSIZE];
	uint32_t dout[DSIZE];
};

volatile struct kuzn_regs *kuzn = (void *) (0x1A118000);

void kuzn_init()
{
	kuzn->rst_n = 0;
}


void kuzn_encrypt_data(const uint32_t * data_for_encryption, uint32_t * encrypted_data)
{
	kuzn_write(data_for_encryption);
	kuzn_read (encrypted_data);
}


void kuzn_write(const uint32_t * data_for_encryption)
{
	while(kuzn->busy);

	for (int i = 0; i < DSIZE; ++i)
		kuzn->din[i] = *(data_for_encryption + i);
	
	kuzn->req_ack = 1;
}


void kuzn_read (uint32_t * encrypted_data)
{
	while(!(kuzn->valid));

	for (int i = 0; i < DSIZE; ++i)
		*(encrypted_data + i) = kuzn->dout[i];

	kuzn->req_ack = 1;
}
