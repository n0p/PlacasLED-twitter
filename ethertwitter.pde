//  Copyright (C) 2010 Georg Kaindl
//  http://gkaindl.com
//
//  This file is part of Arduino EthernetDHCP.
//
//  EthernetDHCP is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Lesser General Public License as
//  published by the Free Software Foundation, either version 3 of
//  the License, or (at your option) any later version.
//
//  EthernetDHCP is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Lesser General Public License for more details.
//
//  You should have received a copy of the GNU Lesser General Public
//  License along with EthernetDHCP. If not, see
//  <http://www.gnu.org/licenses/>.
//

//  Illustrates how to use EthernetDHCP in polling (non-blocking)
//  mode.

#if defined(ARDUINO) && ARDUINO > 18
#include <SPI.h>
#endif
#include <Ethernet.h>
#include <EthernetDHCP.h>
int count = 0;
int max_count = 10;

byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte ip[] = { 192,168,1,108 };
byte gw[] = { 192,168,1,108 };
byte dns[] = { 255,255,255,0 };
const char* ip_to_str(const uint8_t*);

byte server[] = { 199,59,148,201 };

Client client(server, 80);

char c;

//variables para el parseo
    int enString = 0;
    int leeNombre = 1;
    int leeValor = 0;
    int punteroNombre = 0;
    int punteroValor = 0;
    int textFound = 0; 
    int userFound = 0;  
    int idFound = 0;  
    
    int vacia;
    
    char valor[145];
    char nombre[15];


//variables para bucle



  
  



void setup()
{
  Serial.begin(9600);
  
  // Initiate a DHCP session. The argument is the MAC (hardware) address that
  // you want your Ethernet shield to use. The second argument enables polling
  // mode, which means that this call will not block like in the
  // SynchronousDHCP example, but will return immediately.
  // Within your loop(), you can then poll the DHCP library for its status,
  // finding out its state, so that you can tell when a lease has been
  // obtained. You can even find out when the library is in the process of
  // renewing your lease.
  EthernetDHCP.begin(mac, 1);
}

void loop()
{
  static DhcpState prevState = DhcpStateNone;
  static unsigned long prevTime = 0;
  
  // poll() queries the DHCP library for its current state (all possible values
  // are shown in the switch statement below). This way, you can find out if a
  // lease has been obtained or is in the process of being renewed, without
  // blocking your sketch. Therefore, you could display an error message or
  // something if a lease cannot be obtained within reasonable time.
  // Also, poll() will actually run the DHCP module, just like maintain(), so
  // you should call either of these two methods at least once within your
  // loop() section, or you risk losing your DHCP lease when it expires!
  DhcpState state = EthernetDHCP.poll();
  
  
  
  if (prevState != state) {
    Serial.println();

    switch (state) {
      case DhcpStateDiscovering:
        Serial.print("Discovering servers.");
        break;
      case DhcpStateRequesting:
        Serial.print("Requesting lease.");
        break;
      case DhcpStateRenewing:
        Serial.print("Renewing lease.");
        break;
      case DhcpStateLeased: {
        Serial.println("Obtained lease!");

        // Since we're here, it means that we now have a DHCP lease, so we
        // print out some information.
        const byte* ipAddr = EthernetDHCP.ipAddress();
        const byte* gatewayAddr = EthernetDHCP.gatewayIpAddress();
        const byte* dnsAddr = EthernetDHCP.dnsIpAddress();

        Serial.print("My IP address is ");
        Serial.println(ip_to_str(ipAddr));

        Serial.print("Gateway IP address is ");
        Serial.println(ip_to_str(gatewayAddr));

        Serial.print("DNS IP address is ");
        Serial.println(ip_to_str(dnsAddr));

        Serial.println();
        ip[0] = ipAddr[0]; 
        ip[1] = ipAddr[1]; 
        ip[2] = ipAddr[2];
        ip[3] = ipAddr[3];
        
        gw[0] = gatewayAddr[0]; 
        gw[1] = gatewayAddr[1]; 
        gw[2] = gatewayAddr[2];
        gw[3] = gatewayAddr[3];
        
           
        Ethernet.begin(mac,ip,gw,dns);
        
        break;
      }
    }
  } else if (state != DhcpStateLeased && millis() - prevTime > 300) {
     prevTime = millis();
     Serial.print('.'); 
  }
  
  if (state == DhcpStateLeased){
   //programa principal solo si está conectado
    
    Serial.println("twitter!\n");
   
    delay(1000);
    
    Serial.println("connecting...");
    if (client.connect()) {
      Serial.print("connected and retrieving tweet:");
      
      // Make a HTTP request:

        if (count > max_count || count == 0) {
          Serial.println('1');
          client.println("GET /search.json?q=%23pruebas&rpp=1&lang=es HTTP/1.1 ");
          count = 1;
        } else {
          Serial.println(count);
          client.print("GET /search.json?q=%23pruebas&rpp=1&lang=es&page=");
          client.print(count);
          client.println(" HTTP/1.1 ");
        }
        count = count +1;
        client.println("Host: search.twitter.com");
        client.println("Accept: application/json;q=1");
        client.println();
    } 
    else {
      // kf you didn't get a connection to the server:
      Serial.println("connection failed");
    }
    delay(400);
    
    //tratamos el resultado de la API
    vacia = 1;
    
    while (client.available()) {
	c = client.read();
	//Serial.print(c);
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

    //hemos saltado las cabeceras y procedemos con el json
    

    
    while (client.available()) {
      c = client.read();
      //Serial.println(c);
      delay(2);
      switch (c) {
      case '{':
      case '}':
      case '[':
      case ']':
        leeNombre = 1;
        leeValor = 0;
        punteroNombre = 0;
        punteroValor = 0;
        break;
      case '"':
        if (enString) {
          if (leeNombre) {
            nombre[punteroNombre] = '\0';
            //Serial.print("Nombre: ");
            //Serial.println(nombre);
            if (nombre[0] == 't' && nombre[4] == '\0'){
              textFound = 1;
            }
            if (nombre[0] == 'f' && nombre[9] == '\0' ){
              userFound = 1;
            }
           
          }
          else {
            valor[punteroValor] = '\0';
            //Serial.print("Valor: ");
            //Serial.println(valor);
            if (textFound) {
               textFound = 0;
               Serial.print("***Guarda en SD texto: ");
               Serial.println(valor); 
               client.stop();
            }
            if (userFound) {
               userFound = 0;
               Serial.print("***Guarda en SD user: ");
               Serial.println(valor); 
              
            }
          }
        }
        enString = !enString;
        punteroNombre = 0;
        punteroValor = 0;
        break;
      case ':':
        leeNombre = 0;
        leeValor = 1;
        break;
      case ',':
        leeNombre = 1;
        leeValor = 0;
        break;
      case ' ':
      case '\n':
      case '\r':
      case '\t':
      default:
        if (!enString)
          break;
        if (leeNombre) {
          nombre[punteroNombre] = c;
          punteroNombre++;
        }
        else {
          valor[punteroValor] = c;
          punteroValor++;
        }
      }
    }
    

    Serial.println("disconnecting.");
    client.stop();
    

    delay(10000);
    
  }

  
  prevState = state;
}

// Just a utility function to nicely format an IP address.
const char* ip_to_str(const uint8_t* ipAddr)
{
  static char buf[16];
  sprintf(buf, "%d.%d.%d.%d\0", ipAddr[0], ipAddr[1], ipAddr[2], ipAddr[3]);
  return buf;
}
