/***********************************************************************************
 * Copyright (C) 2024 Kirill Turintsev <billiscreezo228@gmail.com>
 * See LICENSE file for licensing details.
 *
 * This file contains declaration of functions for working with the encryption module
 *
 ***********************************************************************************/

#ifndef KUZN_H_
#define KUZN_H_
	void kuzn_init();
	void kuzn_encrypt_data(const uint32_t *, uint32_t *);

	enum
	{
		DSIZE = 4
	};
#endif