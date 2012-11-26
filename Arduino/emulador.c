#include <SDL/SDL.h>
#include <SDL/SDL_video.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>

#define W 16*9
#define H 16

int initTTY(const char *device)
{
	struct termios newtio;
	
	int tty = open(device, O_RDWR | O_NOCTTY);
	
	if (tty < 0)
		return tty;
	
	newtio.c_cflag = B57600 | CRTSCTS | CS8 | 1 | 0 | 0 | CLOCAL | CREAD;
	newtio.c_iflag = IGNPAR;
	newtio.c_oflag = 0;
	newtio.c_lflag = 0;       //ICANON;
	newtio.c_cc[VMIN]=1;
	newtio.c_cc[VTIME]=0;
	tcflush(tty, TCIFLUSH);
	tcsetattr(tty,TCSANOW,&newtio);
	
	return tty;
}

void pixelBuffer(char *buffer, int size, char pixel) {
	int i;
	for (i=size-1; i>0; i--) {
		buffer[i] = buffer[i-1];
	}
	buffer[0] = pixel;
}

void pintarBuffer(char buffer[][H], int width, int height, SDL_Surface *pantalla)
{
	int i,j;
	for (i=0; i<width; i++) {
		for (j=0; j<height; j++) {
			SDL_Rect pixel;
			pixel.x = (width-i-1)*4;
			pixel.y = j*4;
			pixel.w = 4;
			pixel.h = 4;
			
			SDL_FillRect(pantalla, &pixel, 0);
			
			pixel.w = 3;
			pixel.h = 3;
			
			SDL_FillRect(pantalla, &pixel, buffer[i][j]*0xffffffff);
		}
	}
}

int main()
{
	int tty = initTTY("/dev/ttyUSB0");
	if (tty < 0) {
		perror("initTTY");
		return 1;
	}
	
	char buffer[W][H];
	
	SDL_Surface *pantalla = SDL_SetVideoMode(W*4, H*4, 32, SDL_HWSURFACE | SDL_ANYFORMAT);
	
	SDL_Rect blanco;
	blanco.x = 0;
	blanco.y = 0;
	blanco.w = W;
	blanco.h = H;
	
	SDL_FillRect(pantalla, &blanco, 0xffffffff);
	SDL_Flip(pantalla);
	
	SDL_Event event;
		
	int a;
	while(1) {
		char c;
		if (read (tty, &c, 1) == -1) {
			perror("read");
			return 0;
		}
		switch (c) {
		case 'X':
			pixelBuffer((char*)buffer, W*H, 1);
			break;
		case ' ':
			pixelBuffer((char*)buffer, W*H, 0);
			break;
		case '\n':
			pintarBuffer(buffer, W, H, pantalla);
			SDL_Flip(pantalla);
			break;
		}
		
		if (SDL_PollEvent(&event)) {
			if (event.type == SDL_QUIT || 
					(event.type == SDL_KEYDOWN && event.key.keysym.sym == SDLK_ESCAPE)) {
				SDL_FreeSurface(pantalla);
				break;
			}
		}
	}
	
	return 0;
}

