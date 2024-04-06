#include <stdint.h>

typedef struct {
  unsigned long long data[3];
} CXFileUniqueID;

struct {
  int Value;
  uint8_t String[4];
} MyArray_t;

typedef struct {
  int offset;
  int dataType;
  union {
    char *sdata;
    int idata;
  } u;
} F_TextItemT;

typedef struct
{
  uint8_t len;
  F_TextItemT *val;
} F_TextItemsT;