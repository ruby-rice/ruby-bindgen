#ifndef PROJ_EXPERIMENTAL_H
#define PROJ_EXPERIMENTAL_H

/* Experimental PROJ API functions for testing multi-file FFI generation */

struct PJ_CONTEXT;
struct PJ;

int proj_coordoperation_is_instantiable(struct PJ_CONTEXT *ctx, const struct PJ *coordoperation);

const char *proj_coordoperation_get_method_info(struct PJ_CONTEXT *ctx, const struct PJ *coordoperation,
                                                 const char **method_name);

int proj_coordoperation_get_param_count(struct PJ_CONTEXT *ctx, const struct PJ *coordoperation);

#endif /* PROJ_EXPERIMENTAL_H */
