#include <SDL/SDL.h>
#include <SDL/SDL_video.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

struct cabecerabmf {
	uint8_t magicword[5];
	uint8_t altura;
	uint32_t tamano;
	uint16_t padding;
	uint32_t punteros[256]; 
}
__attribute__((__packed__));

struct letra {
	int alto;
	int ancho;
	uint8_t **bitmap;
};

struct letra letras[256];

void cargarLetras()
{
	FILE *bmf;
	struct cabecerabmf cabecera;
	uint8_t ancho, alto;
	
	bmf = fopen("letras.bmf", "rb");
	if (bmf == NULL) {
		perror("No se puede abrir \"letras.bmf\" para lectura");
		return;
	}
	
	// Inicializo el array
	memset(letras, 0, sizeof(letras));
	
	// Leo la cabecera y obtengo el alto de la fuente (en este caso será 16)
	fread(&cabecera, sizeof(struct cabecerabmf), 1, bmf);
	alto = cabecera.altura;
	
	int i;
	for (i=0; i<256; i++) {
		int j,k;
		// Si el puntero es 0 es porque la letra no existe para ese código
		if (cabecera.punteros[i] == 0)
			continue;
		
		// Me voy a donde está la letra y obtengo el ancho
		fseek(bmf, ntohl(cabecera.punteros[i]), SEEK_SET);
		fread(&ancho, 1, 1, bmf);
		
		letras[i].alto = alto;
		letras[i].ancho = ancho;
		
		// Reservo espacio
		letras[i].bitmap = malloc(sizeof(uint8_t *)*ancho);
		for (j=0; j<ancho; j++) {
			letras[i].bitmap[j] = malloc(sizeof(uint8_t)*alto);
		}
		
		uint8_t bitmap = 0;
		int bit = 7;
		fread(&bitmap, 1, 1, bmf);
		
		// Comienzo a rellenar el bitmap
		for (j=0; j<alto; j++) {
			for (k=0; k<ancho; k++) {
				if (bitmap&(0x01<<bit))
					letras[i].bitmap[k][j] = 0;
				else
					letras[i].bitmap[k][j] = 1;
					
				bit--;
				if (bit<0) {
					bit = 7;
					fread(&bitmap, 1, 1, bmf);
				}
			}
		}
	}
	
	fclose(bmf);
}

void liberarLetras() {
	int i,j;
	for (i=0; i<256; i++) {
		if (letras[i].alto==0)
			continue;
		
		for (j=0; j<letras[i].ancho; j++)
			free(letras[i].bitmap[j]);
		free(letras[i].bitmap);
	}
}

void pintarPixel(SDL_Surface *pantalla, int x, int y, Uint32 color)
{
	if (x<0 || y<0 || x>=pantalla->w || y>=pantalla->h)
		return;
	
	((Uint32 *)(pantalla->pixels))[y*pantalla->w + x] = color;
}

void pintarLetra(SDL_Surface *pantalla, unsigned char letra, int x, int y) {
	int i,j;
	for (i=0; i<letras[letra].alto; i++) {
		for (j=0; j<letras[letra].ancho; j++) {
			pintarPixel(pantalla, x+j, y+i, letras[letra].bitmap[j][i]*0xffffffff);
		}
	}
}

void pintarMensaje(SDL_Surface *pantalla) {
	unsigned char mensaje[225];
	int x = 10, y = 10;
	int i;
	
	for (i=0; i<224; i++)
		mensaje[i] = i+32;
	
	mensaje[224] = 0;
	
	strcpy(mensaje, "El veloz murciélago hindú comía feliz cardillo y kiwi. La cigüeña tocaba el saxofón detrás del palenque de paja. ¿0123456789? ¡@!");
	
	for (i=0; i<strlen((char *)mensaje); i++) {
		if (letras[mensaje[i]].ancho == 0) continue;
		if (x+letras[mensaje[i]].ancho >= pantalla->w) {
			x = 10;
			y += 20;
		}
		pintarLetra(pantalla, mensaje[i], x, y);
		x += letras[mensaje[i]].ancho + 2;
	}
}

#define W 800
#define H 100

int main(int argc, char **argv)
{
	cargarLetras();
	
	SDL_Surface *pantalla = SDL_SetVideoMode(W, H, 32, SDL_HWSURFACE | SDL_ANYFORMAT);
	
	SDL_Rect blanco;
	blanco.x = 0;
	blanco.y = 0;
	blanco.w = W;
	blanco.h = H;
	
	SDL_FillRect(pantalla, &blanco, 0xffffffff);
	SDL_Flip(pantalla);
	
	SDL_LockSurface(pantalla);
	
	pintarMensaje(pantalla);
	
	SDL_UnlockSurface(pantalla);
	
	SDL_Flip(pantalla);
	
	scanf("lel");
	
	liberarLetras();

	return 0;
}

