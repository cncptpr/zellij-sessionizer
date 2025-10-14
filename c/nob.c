#define NOBDEF static inline
#define NOB_IMPLEMENTATION
#define NOB_STRIP_PREFIX
#define NOB_EXPERIMENTAL_DELETE_OLD
#define NOB_WARN_DEPRECATED
#include "nob.h"

int main(int argc, char **argv) {
  NOB_GO_REBUILD_URSELF(argc, argv);

  Cmd cmd = {0};
  nob_cmd_append(&cmd, "cc","-g", "-Wall", "-Wextra", "-Werror", "-o", "./zellij-sessionizer", "./zellij-sessionizer.c");
  if (!nob_cmd_run(&cmd))
    return 1;
  return 0;
}
