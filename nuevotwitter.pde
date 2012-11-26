#if defined(ARDUINO) && ARDUINO > 18
#include <SPI.h>
#endif
#include <Ethernet.h>
#include <EthernetDHCP.h>  // Esta librería no es estándar y debe ser la versión modificada que hice. La original tenía bugs :P
#include <avr/pgmspace.h>

// Watchdog
#include <avr/wdt.h>  

#define JSON_ERROR 0
#define JSON_STRING 1
#define JSON_ARRAY 2
#define JSON_OBJECT 3
#define JSON_NUMBER 4
#define JSON_TRUE 5
#define JSON_FALSE 6
#define JSON_NULL 7

#define JSON_STATE_CLEAN 0
#define JSON_STATE_INSTRING 1
#define JSON_STATE_INNUMBER 2
#define JSON_STATE_INOBJECT 3
#define JSON_STATE_INARRAY 4
#define JSON_STATE_INTRUE 5
#define JSON_STATE_INFALSE 6
#define JSON_STATE_INNULL 7

#define DELAY 15

struct json_state {
  char lastRead;
  uint8_t state;
};

/*
 * Cosas que se pueden cambiar.
 */
// Quitar este define si no se usa el simulador de paneles y tener salida de debug por el puerto serie.
//#define SERIAL_SCREEN
// Dirección MAC del ethernet shield
byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
// Dirección IP de search.twitter.com (puede que siga siendo la misma, esto no tiene DNS)
byte server[] = { 199,59,148,201 };
// Hashtag de la búsqueda (sin '#')
char hashtag [] = "murcialanparty";
// Results per page (número de resultados que devuelve la búsqueda en twitter)
int rpp = 3;
// Número máximo de páginas a explorar. El algoritmo va pidiendo las páginas en orden, y luego vuelve a pedir la primera. Cada página contiene rpp tweets.
int maxPage = 10;

Client client(server, 80);

const char* ip_to_str(const uint8_t*);

#define printp(s) _printp(PSTR(s))
#define printlnp(s) _printlnp(PSTR(s))
#define clientPrintp(c,s) _clientPrintp(c,PSTR(s))
#define clientPrintlnp(c,s) _clientPrintlnp(c,PSTR(s))

void _printp(const char *data)
{
  while(pgm_read_byte(data) != 0x00)
    Serial.print(pgm_read_byte(data++));
}

void _printlnp(const char *data)
{
  while(pgm_read_byte(data) != 0x00)
    Serial.print(pgm_read_byte(data++));
  Serial.println();
}

void _clientPrintp(Client &client, const char *data)
{
  while(pgm_read_byte(data) != 0x00)
    client.print(pgm_read_byte(data++));
}

void _clientPrintlnp(Client &client, const char *data)
{
  while(pgm_read_byte(data) != 0x00)
    client.print(pgm_read_byte(data++));
  client.println();
}

uint16_t utf82int(uint8_t *str)
{
  uint16_t n;
  if (str[0] <= 0x7f)
    return str[0];
  if (str[0] <= 0xdf) {
    n = ((uint16_t)(str[0] & 0x1f)) << 6;
    n += (uint16_t)(str[1] & 0x3f);
    return n;
  }
  n = ((uint16_t)(str[0] & 0x0f)) << 12;
  n += ((uint16_t)(str[1] & 0x3f)) << 6;
  n += (uint16_t)(str[2] & 0x3f);
  return n;
}

void processString(char *str)
{
  int len = strlen(str);
  int i = 0;
  int j = 0;
  int k;
  char ent[10];
  
  while (i < len) {
    if (str[i] == '&') {
      i++;
      k = 0;
      while (k < 9 && str[i+k] != ';') {
        ent[k] = str[i+k];
        k++;
      }
      i+=k+1;
      ent[k] = '\0';
      if (strcmp(ent, "quot") == 0) {
        str[j] = '"';
        j++;
      }
      else if (strcmp(ent, "apos") == 0) {
        str[j] = '\'';
        j++;
      }
      else if (strcmp(ent, "amp") == 0) {
        str[j] = '&';
        j++;
      }
      else if (strcmp(ent, "lt") == 0) {
        str[j] = '<';
        j++;
      }
      else if (strcmp(ent, "gt") == 0) {
        str[j] = '>';
        j++;
      }
    }
    else {
      uint16_t n = utf82int((uint8_t *)(str+i));
      if (n > 0x007f) {
        if (n <= 0x07ff)
          i+=2;
        else
          i+=3;
        
        if (n == 0x201c || n == 0x201d) {
          str[j++] = '"';
        }
        else if (n == 0x20ac) {
          str[j++] = 0xa4;
        }
        else if (n == 0x0160) {
          str[j++] = 0xa6;
        }
        else if (n == 0x0161) {
          str[j++] = 0xa8;
        }
        else if (n == 0x017d) {
          str[j++] = 0xb4;
        }
        else if (n == 0x017e) {
          str[j++] = 0xb8;
        }
        else if (n == 0x0152) {
          str[j++] = 0xbc;
        }
        else if (n == 0x0153) {
          str[j++] = 0xbd;
        }
        else if (n == 0x0178) {
          str[j++] = 0xbe;
        }
        else if (n >= 0x00a0 && n <= 0x00ff) {
          str[j++] = n;
        }
        else
          str[j++] = 0x80;
      }else
        str[j++] = str[i++];
    }
  }
  str[j] = '\0';
}

void setup()
{
  wdt_disable();
  Serial.begin(57600);
  
  // Esto inicializa la tarjeta SD y abre el fichero de la fuente. El fichero debe llamarse
  // "LETRAS.BMF" y debe estar situado en la raíz de la tarjeta. El sistema de ficheros debe
  // ser fat32 por supuesto.
  setupFuente();
  
  // Inicializa unas pocas cosas para el control de los paneles.
  setupPanel();
  
#ifndef SERIAL_SCREEN
  printlnp("Configurando red por DHCP...");
#endif
  
  // Tenemos DHCP :D
  EthernetDHCP.begin(mac);
  
  uint8_t* ipAddr = (uint8_t *)EthernetDHCP.ipAddress();
  uint8_t* gatewayAddr = (uint8_t *)EthernetDHCP.gatewayIpAddress();
  uint8_t* subnetMask = (uint8_t *)EthernetDHCP.subnetMask();
  
#ifndef SERIAL_SCREEN
  printlnp("Configuracion DHCP obtenida.");
#endif

  Ethernet.begin(mac, ipAddr, gatewayAddr, subnetMask);
  
  wdt_enable(WDTO_4S);
}

void pintar_mensaje(const char *usuario, const char *mensaje, int imprimeArroba)
{
  uint8_t buffer[32];
  int ancho, alto, margeni, margend, i;
  
  if (imprimeArroba) {
    wdt_reset();
    getLetra('@', buffer, &ancho, &alto, &margeni, &margend);
    writeLetra(buffer, ancho, margeni, margend);
  }
  
  for (i=0; i<strlen((char *)usuario); i++) {
    wdt_reset();
    getLetra(usuario[i], buffer, &ancho, &alto, &margeni, &margend);
    writeLetra(buffer, ancho, margeni, margend);
  }
  
  getLetra(':', buffer, &ancho, &alto, &margeni, &margend);
  writeLetra(buffer, ancho, margeni, margend);
  getLetra(' ', buffer, &ancho, &alto, &margeni, &margend);
  writeLetra(buffer, ancho, margeni, margend);
  
  for (i=0; i<strlen((char *)mensaje); i++) {
    wdt_reset();
    getLetra(mensaje[i], buffer, &ancho, &alto, &margeni, &margend);
    writeLetra(buffer, ancho, margeni, margend);
  }
  
  for (i=0; i<16*10; i++) {
    wdt_reset();
    lineaPanel(0);
    flip();
    delay(DELAY);
  }
}

#define FINISH() client.stop(); EthernetDHCP.maintain()

#define NAMELEN 16
#define USUARIOLEN 16
#define MENSAJELEN 256

int connect_to_twitter(int num)
{
  char c;
  int vacia;
  
#ifndef SERIAL_SCREEN
  printlnp("Conectando a Twitter");
#endif
  if (!client.connect()) {
#ifndef SERIAL_SCREEN
    printlnp("Error al conectar");
#endif
    FINISH();
    return 0;
  }

#ifndef SERIAL_SCREEN  
  printlnp("Conectado");
  
  printlnp("Mandando peticion http...");
#endif
  
  clientPrintp(client, "GET /search.json?q=%23");
  client.print(hashtag);
  clientPrintp(client, "&rpp=1");
  clientPrintp(client, "&page=");
  client.print(num);
  clientPrintlnp(client, " HTTP/1.1");
  clientPrintlnp(client, "Host: search.twitter.com");
  clientPrintlnp(client, "Accept: application/json;q=1");
  // Según la documentación de twitter es "bueno" mandar un user agent... si no lo haces el limitador puede volverse nazi contigo.
  clientPrintlnp(client, "User-Agent: Arduino-Panel/1.0");
  clientPrintlnp(client, "Connection: close");
  client.println();
  
  // Espero a que haya datos por leer
  while (!client.available())
    if (client.status() == 0x00) {
#ifndef SERIAL_SCREEN
      printlnp("Conexion perdida");
#endif
      FINISH();
      return 0;
    }
#ifndef SERIAL_SCREEN    
  printlnp("Saltando cabecera http...");
#endif
    
  while (client.available()) {
    c = client.read();
    if (c != '\n' && c != '\r' && vacia) {
      vacia = 0;
      continue;
    }
    if (c == '\n' && !vacia) {
      vacia = 1;
      continue;
    }
    if (c == '\n' && vacia)
      break;
  }
  
  return 1;
}

int twitter_get_first_id(int64_t *id)
{
  if (!connect_to_twitter(1))
    return 0;

#ifndef SERIAL_SCREEN  
  printlnp("Amos a leer el json");
#endif
  
  int type;
  char name[NAMELEN];
  struct json_state jstate;
  
  // Antes de empezar ponemos cadenas vacias
  name[0] = '\0';
  
  jsonInit(jstate);
  
  jsonStartObject(client, jstate);
  
  while (!jsonObjectEnd(client, jstate)) {
    type = jsonNextVariable(client, jstate, name, NAMELEN);
    
    if (type == JSON_ARRAY && strcmp(name, "results") == 0) {
      jsonStartArray(client, jstate);
      
      while (!jsonArrayEnd(client, jstate)) {
        // El array solo contiene objetos
        jsonStartObject(client, jstate);
        while (!jsonObjectEnd(client, jstate)) {
          type = jsonNextVariable(client, jstate, name, NAMELEN);
          if (type == JSON_NUMBER && strcmp(name, "id") == 0) {
            *id = jsonGetInteger(client, jstate);
          }
          else {
            jsonConsumeValue(client, jstate);
          }
        }

#ifndef SERIAL_SCREEN
        printp("Id: ");
        Serial.println((long)(*id));
        Serial.println();
#endif
      }
    }else {
      jsonConsumeValue(client, jstate);
    }
  }
  FINISH();
  return 1;
}

int twitter_get_message(int num, char *usuario, char *mensaje, int64_t *id)
{
  if (!connect_to_twitter(num))
    return 0;

#ifndef SERIAL_SCREEN  
  printlnp("Amos a leer el json");
#endif
  
  int type;
  char name[NAMELEN];
  struct json_state jstate;
  
  // Antes de empezar ponemos cadenas vacias
  name[0] = '\0';
  usuario[0] = '\0';
  mensaje[0] = '\0';
  
  jsonInit(jstate);
  
  jsonStartObject(client, jstate);
  
  while (!jsonObjectEnd(client, jstate)) {
    type = jsonNextVariable(client, jstate, name, NAMELEN);
    
    if (type == JSON_ARRAY && strcmp(name, "results") == 0) {
      jsonStartArray(client, jstate);
      
      while (!jsonArrayEnd(client, jstate)) {
        // El array solo contiene objetos
        jsonStartObject(client, jstate);
        while (!jsonObjectEnd(client, jstate)) {
          type = jsonNextVariable(client, jstate, name, NAMELEN);
          if (type == JSON_STRING && strcmp(name, "from_user") == 0) {
            jsonGetString(client, jstate, usuario, USUARIOLEN);
          }
          else if (type == JSON_STRING && strcmp(name, "text") == 0) {
            jsonGetString(client, jstate, mensaje, MENSAJELEN);
          }
          else if (type == JSON_NUMBER && strcmp(name, "id") == 0) {
            *id = jsonGetInteger(client, jstate);
          }
          else {
            jsonConsumeValue(client, jstate);
          }
        }
        
        processString(mensaje);
        processString(usuario);

#ifndef SERIAL_SCREEN        
        printp("Nombre de usuario: ");
        Serial.println(usuario);
        printp("Mensaje: ");
        Serial.println(mensaje);
        printp("Id: ");
        Serial.println((long)(*id));
        Serial.println();
#endif
      }
    }else {
      jsonConsumeValue(client, jstate);
    }
  }
  FINISH();
  return 1;
}

int64_t first_id = 0;
int pag = 1;
int published = 0;

void loop()
{
  char usuario[USUARIOLEN];
  char mensaje[MENSAJELEN];
  int64_t id;
  
  wdt_reset();
  
  if (!twitter_get_first_id(&id))
    return;
  
  if (id > first_id) {
    pag = 1;
    first_id = id;
  }
  
  if (!twitter_get_message(pag, usuario, mensaje, &id))
    return;
  
  pag++;
  
  if (mensaje[0] == 0) {
    pag = 1;
    return;
  }
  
  if (published % 10 == 0)
    pintar_mensaje("Paneles de LED", "Publica un tweet con el hashtag \"#MurciaLanParty\" y tu mensaje saldr\xe1 aqu\xed.", 0);
  
  pintar_mensaje(usuario, mensaje, 1);
  
  published++;
}

