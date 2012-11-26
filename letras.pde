#include <SdFat.h>
#include <SdFatUtil.h>

Sd2Card card;
SdFile fuente;
SdFile root;
SdVolume volume;

#define error(s) error_P(PSTR(s))

uint32_t chendianl(uint32_t data) {
  uint32_t ret = 0;
  ret |= (data & 0xff000000)>>24;
  ret |= (data & 0x00ff0000)>>8;
  ret |= (data & 0x0000ff00)<<8;
  ret |= (data & 0x000000ff)<<24;
  return ret;
}

// Maravillosa funcion de error. Simplemente manda un mensaje por el puerto serie
// y se queda parpadeando el led de la placa de arduino indefinidamente.
// Si el programa se queda colgado y el led parpadea, es que ha habido un error
// leyendo la tarjeta SD.
void error_P(const char* str) {
  PgmPrint("error: ");
  SerialPrintln_P(str);
  if (card.errorCode()) {
    PgmPrint("SD error: ");
    Serial.print(card.errorCode(), HEX);
    Serial.print(',');
    Serial.println(card.errorData(), HEX);
  }
  pinMode(13, OUTPUT);
  while(1) {
    digitalWrite(13, HIGH);
    delay(1000);
    digitalWrite(13, LOW);
    delay(1000);
  }
}

void setupFuente() { 
  pinMode(10, OUTPUT);
  digitalWrite(10, HIGH);
  if (!card.init(SPI_FULL_SPEED,4)) error("card.init failed");
  // initialize a FAT volume
  if (!volume.init(&card)) error("volume.init failed");
  // open the root directory
  if (!root.openRoot(&volume)) error("openRoot failed");
  if (!fuente.open(&root, "LETRAS.BMF", O_READ)) error("Error abriendo el fichero de fuente.");;
}

void getLetra(uint8_t letra, uint8_t *buffer, int *_ancho, int *_alto, int *_margeni, int *_margend) {
  uint8_t ancho, alto, margeni, margend, margens;
  uint32_t direccion;
  
  // Primero nos vamos a la posicion de la letra en la tabla
  if (!fuente.seekSet(((uint32_t)letra)*4+16)) error("Error al hacer seek 1");
  if (fuente.read(&direccion, sizeof(uint32_t)) == -1) error("Error al leer");
  
  if (direccion == 0) {
    memset(buffer, 0xff, 32);
    *_ancho = 12;
    *_alto = 16;
    *_margend = 1;
    *_margeni = 1;
    return;
  }
  
  if (!fuente.seekSet(chendianl(direccion))) error("Error al hacer seek 2");
  fuente.read(&ancho, 1);
  fuente.read(&alto, 1);
  fuente.read(&margeni, 1);
  fuente.read(&margend, 1);
  fuente.read(&margens, 1);
  
  memset(buffer, 0, 32);
  
  // Margen superior
  int i,j,bit=-1;
  uint8_t bitmap = 0;
  for (i=0; i<margens; i++) {
    for (j=0; j<ancho; j++) {
      if (bit<0) {
        bitmap = 0;
        bit = 7;
      }
      writeBit((bitmap&(0x01<<bit))!=0, j, i, buffer);				
      bit--;
    }
  }
  // bitmap
  bit = -1;
  for (i=margens; i<alto+margens; i++) {
    for (j=0; j<ancho; j++) {
      if (bit<0) {
        bit = 7;
        fuente.read(&bitmap, 1);
      }
      writeBit((bitmap&(0x01<<bit))!=0, j, i, buffer);				
      bit--;
    }
  }
  // Margen inferior
  for (i=alto+margens; i<16; i++) {
    for (j=0; j<ancho; j++) {
      if (bit<0) {
        bitmap = 0;
        bit = 7;
      }
      writeBit((bitmap&(0x01<<bit))!=0, j, i, buffer);				
      bit--;
    }
  }
  
  *_alto = 16;
  *_ancho = ancho;
  *_margend = margend;
  *_margeni = margeni;
}

