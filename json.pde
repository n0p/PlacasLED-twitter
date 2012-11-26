/*
 * Librería que parsea json "on-line", es decir, sin guardar nada en memoria y sin posibilidad de volver atrás.
 * Está incompleta, solo funciona para el subconjunto de json necesario para interpretar el json que te
 * manda el API de búsqueda de twitter. Tampoco maneja bien errores, básicamente asume que el json está bien formado.
 */

#define WHITESPACE(c) (c == ' ' || c == '\t' || c == '\r' || c == '\n')
#define NUMBER(c) (c == '-' || c == '.' || (c >= '0' && c <= '9'))

#define WAITAVAILABLE while (!client.available()) { if (client.status() == 0) Serial.println(client.status()); return; }
#define WAITAVAILABLER(r) while (!client.available()) { if (client.status() == 0) return(r); Serial.println(client.status()); }
//#define WAITAVAILABLER(r) while(1);

#define MIN(a,b) ((a)<(b)?(a):(b))

void jsonInit (struct json_state &jstate)
{
  jstate.lastRead = '\0';
  jstate.state = JSON_STATE_CLEAN;
}

void jsonStartObject (Client &client, struct json_state &jstate)
{
  if (jstate.state == JSON_STATE_INOBJECT) {
    jstate.state = JSON_STATE_CLEAN;
    return;
  }
  char c;
  while (1) {
    WAITAVAILABLE;
    c = client.read();
    if (c == '{')
      return;
  }
}

void jsonConsumeValue (Client &client, struct json_state &jstate)
{
  char c;
  int level;
  switch (jstate.state) {
  case JSON_STATE_CLEAN:
    while (1) {
      WAITAVAILABLE;
      c = client.read();
      if (WHITESPACE(c)) {
        continue;
      }
        
      jstate.lastRead = c;
      if (c == '"') {
        jstate.state = JSON_STATE_INSTRING;
      }
      else if (NUMBER(c)) {
        jstate.state = JSON_STATE_INNUMBER;
      }
      else if (c == 't') {
        jstate.state = JSON_STATE_INTRUE;
      }
      else if (c == 'f') {
        jstate.state = JSON_STATE_INFALSE;
      }
      else if (c == 'n') {
        jstate.state = JSON_STATE_INNULL;
      }
      else if (c == '[') {
        jstate.state = JSON_STATE_INARRAY;
      }
      else if (c == '{') {
        jstate.state = JSON_STATE_INOBJECT;
      }
      else {
        return;
      }
      jsonConsumeValue(client, jstate);
      return;
    }
    break;
    
  case JSON_STATE_INSTRING:
    jsonGetString(client, jstate, NULL, 0);
    break;
    
  case JSON_STATE_INNUMBER:
    while (1) {
      WAITAVAILABLE;
      c = client.read();
      if (!NUMBER(c)) {
        jstate.lastRead = c;
        break;
      }
    }
    break;
  
  case JSON_STATE_INOBJECT:
    level = 0;
    while (1) {
      WAITAVAILABLE;
      c = client.read();
      if (c == '"') {
        jstate.state = JSON_STATE_INSTRING;
        jsonGetString(client, jstate, NULL, 0);
        continue;
      }
      if (c == '}' && level == 0)
        break;
      if (c == '}')
        level--;
      else if (c == '{')
        level++;
    }
    break;
  
  case JSON_STATE_INARRAY:
    level = 0;
    while (1) {
      WAITAVAILABLE;
      c = client.read();
      if (c == '"') {
        jstate.state = JSON_STATE_INSTRING;
        jsonGetString(client, jstate, NULL, 0);
        continue;
      }
      if (c == ']' && level == 0)
        break;
      if (c == ']')
        level--;
      else if (c == '[')
        level++;
    }
    break;
    
    case JSON_STATE_INTRUE:
    case JSON_STATE_INFALSE:
    case JSON_STATE_INNULL:
      while (1) {
        WAITAVAILABLE;
        c = client.read();
        if (c < 'a' || c > 'z') {
          jstate.lastRead = c;
          break;
        }
      }
    break;
  }
  jstate.state = JSON_STATE_CLEAN;
}

void jsonStartArray (Client &client, struct json_state &jstate)
{
  if (jstate.state == JSON_STATE_INARRAY) {
    jstate.state = JSON_STATE_CLEAN;
    return;
  }
  char c;
  while (1) {
    WAITAVAILABLE;
    c = client.read();
    if (c == '{')
      return;
  }
}

int jsonObjectEnd (Client &client, struct json_state &jstate)
{
  if (jstate.state != JSON_STATE_CLEAN)
    return 0;
  if (jstate.lastRead == '}') {
    jstate.lastRead = '\0';
    return 1;
  }
  char c;
  while (1) {
    WAITAVAILABLER(1);
    c = client.read();
    if (WHITESPACE(c)) {
      continue;
    }
    else if (c == '}') {
      return 1;
    }
    else {
      if (c == '"') {
        jstate.state = JSON_STATE_INSTRING;
        jstate.lastRead = c;
      }
      return 0;
    }
  }
}

int jsonArrayEnd (Client &client, struct json_state &jstate)
{
  if (jstate.state != JSON_STATE_CLEAN)
    return 0;
  if (jstate.lastRead == ']') {
    jstate.lastRead = '\0';
    return 1;
  }
  char c;
  while (1) {
    WAITAVAILABLER(1);
    c = client.read();
    if (WHITESPACE(c)) {
      continue;
    }
    else if (c == ']') {
      return 1;
    }
    else {
      jstate.lastRead = c;
      if (c == '"') {
        jstate.state = JSON_STATE_INSTRING;
      }
      else if (NUMBER(c)) {
        jstate.state = JSON_STATE_INNUMBER;
      }
      else if (c == 't') {
        jstate.state = JSON_STATE_INTRUE;
      }
      else if (c == 'f') {
        jstate.state = JSON_STATE_INFALSE;
      }
      else if (c == 'n') {
        jstate.state = JSON_STATE_INNULL;
      }
      else if (c == '[') {
        jstate.state = JSON_STATE_INARRAY;
      }
      else if (c == '{') {
        jstate.state = JSON_STATE_INOBJECT;
      }
      return 0;
    }
  }
}

int jsonNextVariable(Client &client, struct json_state &jstate, char *name, int len)
{
  jsonGetString(client, jstate, name, len);
  
  while (1) {
    WAITAVAILABLER(1);
    if (client.read() == ':')
      break;
  }
  
  char c;
  while (1) {
    WAITAVAILABLER(1);
    c = client.read();
    if (WHITESPACE(c)) {
      continue;
    }
      
    jstate.lastRead = c;
    if (c == '"') {
      jstate.state = JSON_STATE_INSTRING;
      return JSON_STRING;
    }
    else if (NUMBER(c)) {
      jstate.state = JSON_STATE_INNUMBER;
      return JSON_NUMBER;
    }
    else if (c == 't') {
      jstate.state = JSON_STATE_INTRUE;
      return JSON_TRUE;
    }
    else if (c == 'f') {
      jstate.state = JSON_STATE_INFALSE;
      return JSON_FALSE;
    }
    else if (c == 'n') {
      jstate.state = JSON_STATE_INNULL;
      return JSON_NULL;
    }
    else if (c == '[') {
      jstate.state = JSON_STATE_INARRAY;
      return JSON_ARRAY;
    }
    else if (c == '{') {
      jstate.state = JSON_STATE_INOBJECT;
      return JSON_OBJECT;
    }
    else {
      return JSON_ERROR;
    }
  }
}

int hex2int(char hex)
{
  if (hex >= '0' && hex <= '9')
    return hex-'0';
  if (hex >= 'a' && hex <= 'f')
    return hex-'a'+10;
  if (hex >= 'A' && hex <= 'F')
    return hex-'A'+10;
  return 0;
}

void int2utf8(uint16_t n, char *utf8)
{
  if (n <= 0x007f) {
    utf8[0] = n;
    utf8[1] = 0x00;
    return;
  }
  if (n <= 0x07ff) {
    utf8[0] = 0xc0 + ((n & 0x07c0) >> 6);
    utf8[1] = 0x80 + (n & 0x003f);
    utf8[2] = 0x00;
    return;
  }
  utf8[0] = 0xe0 + ((n & 0xf000) >> 12);
  utf8[1] = 0x80 + ((n & 0x0fc0) >> 6);
  utf8[2] = 0x80 + (n & 0x003f);
  utf8[3] = 0x00;
  return;
}

void jsonGetString(Client &client, struct json_state &jstate, char *string, int len)
{
  if (jstate.state != JSON_STATE_INSTRING) {
    while (1) {
      WAITAVAILABLE;
      if (client.read() == '"')
        break;
    }
  }
  
  jstate.state = JSON_STATE_CLEAN;

  char c;
  boolean scape = false;
  int i = 0;
  int j;
  int ulen;
  uint16_t n;
  char utf8[4];
  while (1) {
    WAITAVAILABLE;
    c = client.read();
    if (scape) {
      if (string != NULL) {
        switch (c) {
        case '\\':
          string[i] = '\\';
          break;
        case '/':
          string[i] = '/';
          break;
        case 'b':
          string[i] = '\b';
          break;
        case 'f':
          string[i] = '\f';
          break;
        case 'n':
          string[i] = '\n';
          break;
        case 'r':
          string[i] = '\r';
          break;
        case 't':
          string[i] = '\t';
          break;
        case 'u':
          n = 0;
          for (j=0; j<4; j++) {
            WAITAVAILABLE;
            c = client.read();
            n += hex2int(c) << ((3-j)*4);
          }
          int2utf8(n, utf8);
          ulen = strlen(utf8);
          ulen = MIN(ulen, len-i);
          for (j=0; j<ulen; j++) {
            string[i+j] = utf8[j];
          }
          i += ulen - 1;
          break;
        default:
          string[i] = c;
        }
        i++;
        if (i >= len)
          i = len - 1;
      }
      scape = false;
    }
    else {
      if (c == '"')
        break;
      if (c == '\\') {
        scape = true;
        continue;
      }
      if (string != NULL) string[i] = c;
      i++;
      if (i == len)
        i--;
    }
  }
  if (string != NULL) string[i] = '\0';
}

int64_t pow_64(int a, int b) {
  int64_t retval = 1;
  
  while (b > 0) {
    retval *= a;
    b--;
  }
  
  return retval;
}

int64_t atoi_64(const char *buffer)
{
  int negative = 0;
  int i = 0;
  if (buffer[0] == '-') {
    negative = 1;
    i++;
  }
  
  int64_t retval = 0;

  while (buffer[i] != 0) {
    i++;
  }
  
  int size = i - 1;
  i = negative;
  
  while (buffer[i] != 0) {
    retval += (buffer[i] - '0') * pow_64(10, size);
    i++;
    size--;
  }
  
  return negative ? -retval : retval;
}

int64_t jsonGetInteger(Client &client, struct json_state &jstate)
{
  char c;
  char buffer[20];
  int i = 0;
  
  if (jstate.state != JSON_STATE_INNUMBER) {
    while (1) {
      WAITAVAILABLER(0);
      c = client.read();
      if (NUMBER(c))
        break;
    }
    buffer[0] = c;
    i++;
  }
  
  jstate.state = JSON_STATE_CLEAN;

  while (1) {
    WAITAVAILABLER(0);
    c = client.read();
    buffer[i] = c;
    
    if (c < '0' || c > '9' || i == 19) {
      buffer[i] = 0;
      break;
    }
    
    i++;
  }
  
  return atoi_64(buffer);
}

