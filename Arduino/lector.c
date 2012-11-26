#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>

struct cabecerabmf {
	uint8_t magicword[5];
	uint8_t altura;
	uint32_t tamano;
	uint16_t padding;
	uint32_t punteros[256]; 
}
__attribute__((__packed__));

int main() {
	FILE *bmf;
	struct cabecerabmf cabecera;
	uint8_t ancho, alto;
	
	bmf = fopen("letras.bmf", "rb");
	if (bmf == NULL) {
		perror("No se puede abrir \"letras.bmf\" para lectura");
		return 1;
	}
	
	// Leo la cabecera y obtengo el alto de la fuente (en este caso será 16)
	fread(&cabecera, sizeof(struct cabecerabmf), 1, bmf);
	alto = cabecera.altura;
	
	int i;
	for (i=0; i<256; i++) {
		// Si el puntero es 0 es porque la letra no existe para ese código
		if (cabecera.punteros[i] == 0)
			continue;
		
		// Me voy a donde está la letra y obtengo el ancho
		fseek(bmf, ntohl(cabecera.punteros[i]), SEEK_SET);
		fread(&ancho, 1, 1, bmf);
		
		uint8_t bitmap = 0;
		int bit = 7;
		fread(&bitmap, 1, 1, bmf);
		
		printf("Carácter %.2x (%dx%d):\n", i, ancho, alto);
		
		// Comienzo a dibujar en la consola (cutre xD)
		int j,k;
		for (j=0; j<alto; j++) {
			for (k=0; k<ancho; k++) {
				if (bitmap&(0x01<<bit))
					printf("##");
				else
					printf("  ");
					
				bit--;
				if (bit<0) {
					bit = 7;
					fread(&bitmap, 1, 1, bmf);
				}
			}
			printf("\n");
		}
	}
	
	return 0;
}

