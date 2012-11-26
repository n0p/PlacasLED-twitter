#define CLOCK 7
#define FLIP 6
#define ENABLE 5
#define DATA 3

void writeBit(uint8_t bitv, int x, int y, uint8_t *dest) {
  uint8_t bytev = dest[y*2+x/8];
  
  bytev |= bitv<<(7-(x%8));
  
  dest[y*2+x/8] = bytev;
}

uint8_t readBit(int x, int y, int ancho, int alto, uint8_t *buffer) {
  uint8_t bytev = buffer[(x+y*ancho)/8];
  
  return (bytev & 0x80>>((x+y*ancho)%8)) != 0;
}

void expandLetra(uint8_t *orig, uint8_t *dest, int ancho, int alto) {
  int i, j;
  
  memset(dest, 0, 32);
  
  int sup = ((alto==10||alto==12)?4:0);
  int inf = ((alto==10||alto==14)?2:0);
  
  // Genero bits en blanco superiores
  for (i=0; i<sup;i++) {
    for (j=0; j<ancho; j++) {
      writeBit(0, j, i, dest);
    }
  }
  for (i=sup; i<alto+sup; i++) {
    for (j=0; j<ancho; j++) {
      writeBit(readBit(j, i-sup, ancho, alto, orig), j, i, dest);
    }
  }
  // Genero bits en blanco inferiores
  for (i=alto+sup; i<inf+alto+sup;i++) {
    for (j=0; j<ancho; j++) {
      writeBit(0, j, i, dest);
    }
  }
}

void flip()
{
  digitalWrite(FLIP, HIGH);
  digitalWrite(FLIP, LOW);
  Serial.print("\n");
}

void lineaPanel(uint16_t linea) {
  int i,j;
  for (j=0; j<16; j++) {
    digitalWrite(DATA, (linea&(0x0001<<(15-j))) != 0);
    digitalWrite(CLOCK, HIGH);
    digitalWrite(CLOCK, LOW);
    if (linea&(0x0001<<(15-j))) Serial.print("X");
    else Serial.print(" ");
  }
}

void writeLetra(uint8_t *buffer, int ancho, int margeni, int margend) {
  int i,j;
  
  for (i=0; i<margeni; i++) {
    lineaPanel(0);
    flip();
    delay(DELAY);
  }
  for (i=0; i<ancho; i++) {
    uint16_t linea = 0;
    for (j=0; j<16; j++) {
      linea |= readBit(i,j,16,16,buffer) << j;
    }
    lineaPanel(linea);
    flip();
    delay(DELAY);
  }
  for (i=0; i<margend; i++) {
    lineaPanel(0);
    flip();
    delay(DELAY);
  }
}

void setupPanel() {
    
  pinMode(CLOCK, OUTPUT);
  pinMode(ENABLE, OUTPUT);
  pinMode(DATA, OUTPUT);
  pinMode(FLIP, OUTPUT);
  
  digitalWrite(CLOCK, LOW);
  digitalWrite(ENABLE, HIGH);
  digitalWrite(DATA, LOW);
  digitalWrite(FLIP, LOW);
  
  int  i;
  
  for (i=0; i<48; i++)
    lineaPanel(0);
}

