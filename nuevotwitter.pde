#if defined(ARDUINO) && ARDUINO > 18
#include <SPI.h>
#endif
#include <Ethernet.h>
#include <EthernetDHCP.h>
#include <avr/pgmspace.h>

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

#define DELAY 10

#define SERIAL_SCREEN

struct json_state {
  char lastRead;
  uint8_t state;
};

byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte server[] = { 199,59,148,201 };
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
  Serial.begin(57600);
  
  setupFuente();
  setupPanel();
  
#ifndef SERIAL_SCREEN
  printlnp("Configurando red por DHCP...");
#endif
  
  EthernetDHCP.begin(mac);
  
  uint8_t* ipAddr = (uint8_t *)EthernetDHCP.ipAddress();
  uint8_t* gatewayAddr = (uint8_t *)EthernetDHCP.gatewayIpAddress();
  uint8_t* subnetMask = (uint8_t *)EthernetDHCP.subnetMask();
  
#ifndef SERIAL_SCREEN
  printlnp("Configuracion DHCP obtenida.");
#endif

  Ethernet.begin(mac, ipAddr, gatewayAddr, subnetMask);
}

#define ENDLOOP() client.stop(); delay(1000); EthernetDHCP.maintain()

#define NAMELEN 16
#define USUARIOLEN 16
#define MENSAJELEN 256

void loop()
{
lcontinue:
  char c;
  int vacia;

#ifndef SERIAL_SCREEN
  printlnp("Conectando a Twitter");
#endif
  if (!client.connect()) {
#ifndef SERIAL_SCREEN
    printlnp("Error al conectar");
#endif
    ENDLOOP();
    goto lcontinue;
  }

#ifndef SERIAL_SCREEN  
  printlnp("Conectado");
  
  printlnp("Mandando peticion http...");
#endif
  
  clientPrintlnp(client, "GET /search.json?q=%23nolesvotes&rpp=10&lang=es HTTP/1.1");
  clientPrintlnp(client, "Host: search.twitter.com");
  clientPrintlnp(client, "Accept: application/json;q=1");
  clientPrintlnp(client, "User-Agent: Arduino-Panel/1.0");
  clientPrintlnp(client, "Connection: close");
  client.println();
  
  // Espero a que hayan datos por leer
  while (!client.available())
    if (client.status() == 0x00) {
#ifndef SERIAL_SCREEN
      printlnp("Conexion perdida");
#endif
      ENDLOOP();
      goto lcontinue;
    }
#ifndef SERIAL_SCREEN    
  printlnp("Saltando cabecera http...");
#endif
  
  vacia = 1;
    
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

#ifndef SERIAL_SCREEN  
  printlnp("Amos a leer el json");
#endif
  
  int type;
  int nmensajes;
  char name[NAMELEN];
  char usuario[USUARIOLEN];
  char mensaje[MENSAJELEN];
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
      nmensajes = 0;
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
          else {
            jsonConsumeValue(client, jstate);
          }
        }
        
        nmensajes++;
        
        processString(mensaje);
        processString(usuario);

#ifndef SERIAL_SCREEN        
        printp("Nombre de usuario: ");
        Serial.println(usuario);
        printp("Mensaje: ");
        Serial.println(mensaje);
        Serial.println();
#endif
        
        uint8_t buffer[32];
        int ancho, alto, margeni, margend, i;
        
        getLetra('@', buffer, &ancho, &alto, &margeni, &margend);
        writeLetra(buffer, ancho, margeni, margend);
        
        for (i=0; i<strlen((char *)usuario); i++) {
          getLetra(usuario[i], buffer, &ancho, &alto, &margeni, &margend);
          writeLetra(buffer, ancho, margeni, margend);
        }
        
        getLetra(':', buffer, &ancho, &alto, &margeni, &margend);
        writeLetra(buffer, ancho, margeni, margend);
        getLetra(' ', buffer, &ancho, &alto, &margeni, &margend);
        writeLetra(buffer, ancho, margeni, margend);
        
        for (i=0; i<strlen((char *)mensaje); i++) {
          getLetra(mensaje[i], buffer, &ancho, &alto, &margeni, &margend);
          writeLetra(buffer, ancho, margeni, margend);
        }
        
        for (i=0; i<16*10; i++) {
          lineaPanel(0);
          flip();
          delay(DELAY);
        }
      }
    }else {
      jsonConsumeValue(client, jstate);
    }
  }

#ifndef SERIAL_SCREEN  
  printlnp("Fin del JSON, terminamos");
  printp("Mensajes leidos: ");
  Serial.println(nmensajes);
  Serial.println();
#endif
  
  ENDLOOP();
}

