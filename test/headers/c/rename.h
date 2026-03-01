typedef enum {
    CS_2D_LONGITUDE_LATITUDE,
    CS_2D_LATITUDE_LONGITUDE
} ELLIPSOIDAL_CS_2D_TYPE;

typedef struct {
    double x, y, z;
} MY_3D_POINT;

MY_3D_POINT* create_ellipsoidal_2D_cs(ELLIPSOIDAL_CS_2D_TYPE type);
