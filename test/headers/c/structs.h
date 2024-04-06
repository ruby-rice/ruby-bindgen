typedef struct {
  unsigned long long data[3];
} CXFileUniqueID;

struct {
  int Value;
  unsigned char String[4];
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
  unsigned char len;
  F_TextItemT *val;
} F_TextItemsT;