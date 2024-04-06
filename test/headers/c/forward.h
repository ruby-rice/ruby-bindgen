

//typedef struct A A;
typedef struct B B;
struct C;
//struct D;
/*
struct E
{
    char* ename;
};*/

typedef struct F
{
  //  A* a;
    B* b;
    struct C* c;
  /*  struct D* d;
    struct E e1;
    struct E* e2;*/
} F;

struct B
{
    char* bname;
};

struct C
{
    char* cname;
};
