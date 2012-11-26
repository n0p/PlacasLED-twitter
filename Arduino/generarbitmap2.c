#include <sys/types.h>
#include <dirent.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#define ishex(C) (((C)>='0' && (C)<='9') || ((C)>='a' && (C)<='z') || ((C)>='A' && (C)<='Z'))
#define BUFTAM 2048

uint8_t hex2byte (char *hex) {
	uint8_t byte = 0;
	int i;
	
	for (i=0; i<2; i++) {
		if (hex[i]>='0' && hex[i]<='9') {
			byte |= (hex[i]-'0')<<(i==0?4:0);
		}else {
			if (hex[i]>='A' && hex[i]<='F') {
				byte |= (hex[i]-'A'+10)<<(i==0?4:0);
			}else {
				byte |= (hex[i]-'a'+10)<<(i==0?4:0);
			}
		}
	}
	return byte;
}


int main() {
	DIR *dp;
	struct dirent *ep;
	unsigned char buffer[BUFTAM];

	if (chdir("letras") == -1) {
		perror("No se puede cambiar al directorio \"letras\"");
		return 1;
	}
	
	int i;
	for (i=0; i<256; i++) {
		int encontrado = 0;
		
		dp = opendir ("./");
		if (!dp) {
			perror("No se puede leerse el directorio \"letras\"");
			return 1;
		}

		while (ep = readdir (dp)) {
			char nombre[32];
	
			uint8_t num;
			num = hex2byte(ep->d_name);
			
			if (num != i)
				continue;
			
			encontrado = 1;
	
			strncpy(nombre, ep->d_name+3, 32);
			if (strlen(nombre)<4)
				continue;
			nombre[strlen(nombre)-4]=0;
			
			printf("_%s,\n", nombre);
			
			/*printf("  case 0x%.2x:\n",num);
			printf("    temp = pgm_read_byte_near(_%s);\n", nombre);
			printf("    *alto = (temp&0x0f)+1;\n");
			printf("    *ancho = ((temp&0xf0)>>4)+1;\n");
			printf("    for (i=0; i<((*alto)*(*ancho))%%8==0?((*alto)*(*ancho)/8):((*alto)*(*ancho)/8+1); i++)\n");
			printf("      buffer[i] = pgm_read_byte_near(_%s + i + 1);\n", nombre);
			printf("    break;\n");*/
		}
		if (!encontrado)
			printf("NULL,\n");
	
		closedir (dp);
	}

	return 0;

}

