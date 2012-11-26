#include <png.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#define ishex(C) ((( C )>='0' && ( C )<='9') || (( C )>='a' && ( C )<='z') || (( C )>='A' && ( C )<='Z'))
#define BUFTAM 2048

struct cabecerabmf {
	uint8_t magicword[5];
	uint8_t version;
	uint8_t altura;
	uint32_t tamano;
	uint8_t padding[5];
	uint32_t punteros[256];
}
__attribute__((__packed__));

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

void generarcabecera(struct cabecerabmf *cabecera, FILE *bmf, uint8_t altura, uint8_t version) {
	const char magicword[] = "\x01\x00\x42\x4d\x46";
	
	memcpy(cabecera->magicword, magicword, 5);
	cabecera->altura = altura;
	cabecera->version = version;
	cabecera->tamano = htonl(ftell(bmf));
	
	rewind(bmf);
	
	fwrite(cabecera, 1, sizeof(struct cabecerabmf), bmf);
}

void generarbitmap(FILE *fp, FILE *bmf, int pos, struct cabecerabmf *cabecera, uint8_t margeni, uint8_t margend, uint8_t margens)
{
	png_uint_32 width, height, color_type, bit_depth;
	
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
	color_type = png_get_color_type(png_ptr, info_ptr);
	bit_depth = png_get_bit_depth(png_ptr, info_ptr);
	width = png_get_image_width(png_ptr, info_ptr);
	height = png_get_image_height(png_ptr, info_ptr);
	
	// Guardo la posición del bitmap en el fichero
	cabecera->punteros[pos] = htonl(ftell(bmf));
	
	// Escribo el ancho, alto y los márgenes
	uint8_t ancho = width;
	uint8_t alto = height;
	fwrite(&ancho, 1, 1, bmf);
	fwrite(&alto, 1, 1, bmf);
	fwrite(&margeni, 1, 1, bmf);
	fwrite(&margend, 1, 1, bmf);
	fwrite(&margens, 1, 1, bmf);
	
	// Empiezo a generar el bitmap
	uint8_t bitmap = 0;
	int bit = 7;
	
	// Obtengo los pixels y los voy guardando
	png_bytep *row_pointers = png_get_rows(png_ptr, info_ptr);
	int i,j;
	for (i=0; i<height; i++) {
		for (j=0; j<width; j++) {
			bitmap |= (row_pointers[i][j*3]==0)<<bit;
			bit--;
			if (bit < 0) {
				fwrite(&bitmap, 1, 1, bmf);
				bitmap = 0;
				bit = 7;
			}
		}
	}
	if (bit!=7) {
		fwrite(&bitmap, 1, 1, bmf);
	}
	
	png_destroy_read_struct(&png_ptr, &info_ptr, &end_info);
}

int main(int argc, char *argv[]) {
	FILE *bmf, *info;
	struct dirent *ep;
	unsigned char buffer[BUFTAM];
	struct cabecerabmf cabecera;
	
	if (argc < 3) {
		fprintf(stderr, "Uso: %s <fichero info> <salida.bmf>\n", argv[0]);
		return 1;
	}
	
	info = fopen(argv[1], "r");
	if (!info) {
		perror(argv[1]);
		return 1;
	}
	
	bmf = fopen(argv[2], "wb");
	if (!bmf) {
		perror(argv[2]);
		return 1;
	}
	
	int altura;
	if (fscanf(info, "%d", &altura) != 1) {
		fprintf(stderr, "Error al leer el fichero de información\n");
		return 1;
	}
	
	// Genero la cabecera para avanzar el puntero de escritura
	memset(&cabecera, 0, sizeof(struct cabecerabmf));
	generarcabecera(&cabecera, bmf, altura, 1);
	
	char nombre [64];
	int i = -1;

	while (fscanf(info, "%64s", nombre) == 1) {
		i++;
		if (strcmp(nombre, "null")==0)
			continue;
		
		int margeni, margend, margens;
		fscanf(info, "%d %d %d", &margeni, &margend, &margens);
		
		FILE *fp = fopen(nombre, "rb");
		if (fp==NULL) {
			fprintf(stderr, "ATENCIÓN: No se puede abrir el fichero \"%s\"\n", nombre);
			continue;
		}
		
		fread(buffer, 1, 8, fp);
		if (png_sig_cmp(buffer, 0, 8)) {
			fprintf(stderr, "ATENCIÓN: El fichero \"%s\" no es PNG\n", nombre);
			fclose(fp);
			continue;
		}
		
		generarbitmap(fp, bmf, i, &cabecera, margeni, margend, margens);
		
		fclose(fp);
	}
	
	// Vuelvo a generar la cabecera
	generarcabecera(&cabecera, bmf, altura, 1);
	
	fclose(bmf);

	return 0;
}

