#include <png.h>
#include <sys/types.h>
#include <dirent.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#define ishex(C) (((C)>='0' && (C)<='9') || ((C)>='a' && (C)<='z') || ((C)>='A' && (C)<='Z'))
#define BUFTAM 2048

int tam = 0;

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

void generarbitmap(FILE *fp, char* _nombre) {
	char nombre[32];
	
	uint8_t pos;
	pos = hex2byte(_nombre);
	
	strncpy(nombre, _nombre+3, 32);
	if (strlen(nombre)<4)
		return;
	nombre[strlen(nombre)-4]=0;

	png_structp png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, (png_voidp)NULL, NULL, NULL);
	if (!png_ptr)
		return;

	png_infop info_ptr = png_create_info_struct(png_ptr);
	if (!info_ptr) {
		png_destroy_read_struct(&png_ptr, (png_infopp)NULL, (png_infopp)NULL);
		return;
	}

	png_infop end_info = png_create_info_struct(png_ptr);
	if (!end_info) {
		png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp)NULL);
		return;
	}
	
	png_set_sig_bytes(png_ptr, 8);
	png_init_io(png_ptr, fp);
	
	png_read_png(png_ptr, info_ptr, PNG_TRANSFORM_STRIP_16 | PNG_TRANSFORM_STRIP_ALPHA | PNG_TRANSFORM_PACKING | PNG_TRANSFORM_GRAY_TO_RGB, NULL);

	// Obtengo información básica
	png_uint_32 width, height, color_type, bit_depth;
	color_type = png_get_color_type(png_ptr, info_ptr);
	bit_depth = png_get_bit_depth(png_ptr, info_ptr);
	width = png_get_image_width(png_ptr, info_ptr);
	height = png_get_image_height(png_ptr, info_ptr);
	
	// Empiezo a generar el bitmap
	uint8_t bitmap = 0;
	int bit = 7;
	printf("PROGMEM prog_uchar _%s[] = {", nombre);
	printf("0x%.1x%.1x", width-1, height-1);
	tam+=1;
	
	//prueba[0] = height<<8 | width;
	
	// Obtengo los pixels
	png_bytep *row_pointers = png_get_rows(png_ptr, info_ptr);
	int i,j;
	for (i=0; i<height; i++) {
		for (j=0; j<width; j++) {
			//printf("%c", row_pointers[i][j*3]==0?'#':' ');
			bitmap |= (row_pointers[i][j*3]==0)<<bit;
			bit--;
			if (bit < 0) {
				printf(",0x%.2x", bitmap);
				bitmap = 0;
				bit = 7;
				tam+=1;
			}
		}
		//printf("\n");
	}
	if (bit!=7) {
		printf(",0x%.2x", bitmap);
		tam+=1;
	}
	printf("};\n");

	png_destroy_read_struct(&png_ptr, &info_ptr, &end_info);
}

int main() {
	DIR *dp;
	struct dirent *ep;
	unsigned char buffer[BUFTAM];

	if (chdir("letras") == -1) {
		perror("No se puede cambiar al directorio \"letras\"");
		return 1;
	}
	dp = opendir ("./");
	if (!dp) {
		perror("No se puede leerse el directorio \"letras\"");
		return 1;
	}

	while (ep = readdir (dp)) {
		if (!(strlen(ep->d_name)>=2 && ishex(ep->d_name[0]) && ishex(ep->d_name[1])))
			continue;
		
		FILE *fp = fopen(ep->d_name, "rb");
		if (fp==NULL) {
			fprintf(stderr, "No se puede abrir el fichero \"%s\"\n", ep->d_name);
			continue;
		}
		
		fread(buffer, 1, 8, fp);
		if (png_sig_cmp(buffer, 0, 8)) {
			fprintf(stderr, "El fichero \"%s\" no es PNG\n", ep->d_name);
			continue;
		}
		
		generarbitmap(fp, ep->d_name);
		
		fclose(fp);
	}
	printf("Tamaño final: %d bytes\n", tam);
	closedir (dp);

	return 0;

}

