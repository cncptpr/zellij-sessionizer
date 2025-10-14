#include <dirent.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define NOB_IMPLEMENTATION
#define NOB_EXPERIMENTAL_DELETE_OLD
#define NOB_WARN_DEPRECATED
#include "nob.h"

#define ANSI_RESET "\x1B[0m"
#define ANSI_RED "\x1B[31m"
#define ANSI_GREEN "\x1B[32m"
#define ANSI_YELLOW "\x1B[33m"

bool is_dir(const char *path) {
  struct stat statbuf;
  return (stat(path, &statbuf) == 0 && S_ISDIR(statbuf.st_mode));
}

bool append_path(Nob_String_Builder *list, const char *path) {
  if (is_dir(path)) {
    nob_sb_appendf(list, "%s\n", path);
    return true;
  }
  return false;
}

bool append_all_paths(Nob_String_Builder *list, const char *path) {
  if (strcmp(path + strlen(path) - 2, "/*") != 0) {
    return append_path(list, path);
  }

  size_t base_len = strlen(path) - 2; // Remove the '/*' suffix
  char *base_path = (char *)malloc(base_len + 1);
  strncpy(base_path, path, base_len);
  base_path[base_len] = '\0';

  if (!is_dir(base_path)) {
    printf(ANSI_YELLOW "Warning:" ANSI_RESET " Directory not found: %s\n",
           base_path);
    free(base_path);
    return false;
  }

  struct dirent *entry;
  DIR *dp = opendir(base_path);
  if (dp == NULL) {
    free(base_path);
    return false;
  }

  while ((entry = readdir(dp)) != NULL) {
    if (strcmp(entry->d_name, ".") != 0 && strcmp(entry->d_name, "..") != 0) {
      char full_path[PATH_MAX];
      snprintf(full_path, sizeof(full_path), "%s/%s", base_path, entry->d_name);
      append_path(list, full_path);
    }
  }
  closedir(dp);
  free(base_path);
  return true;
}

int fzf(const Nob_String_Builder *const list, char *const out_result,
        const int result_length) {
  Nob_String_Builder fzf_cmd = {0};
  nob_sb_appendf(&fzf_cmd, "printf '%%s\\n' '%s' | fzf", list->items);

  FILE *fzf_handle = popen(fzf_cmd.items, "r");
  if (!fzf_handle) {
    printf("" ANSI_RED "Error:" ANSI_RESET " Failed to execute fzf\n");
    return 0;
  }

  if (fgets(out_result, result_length, fzf_handle))
    out_result[strcspn(out_result, "\n")] = 0; // Remove newline

  return pclose(fzf_handle) != -1;
}

int main(int argc, char *argv[]) {
  if (getenv("ZELLIJ") != NULL) {
    printf("" ANSI_RED "Zellij environment detected!" ANSI_RESET "\n"
           "Script only works outside of Zellij.\n\n"
           "This is because nested Zellij sessions are not recommended,\n"
           "and it is currently not possible to change Zellij sessions\n"
           "from within a script.\n\n"
           "Exit Zellij and try again,\n"
           "or unset " ANSI_GREEN "ZELLIJ" ANSI_RESET
           " env var to force this script to work.\n");
    return 1;
  }

  if (argc < 2) {
    printf("No paths were specified, usage: ./zellij-sessionizer path1 path2/* "
           "etc..\n");
    return 1;
  }

  Nob_String_Builder candidates = {0};

  for (int i = 1; i < argc; i++) {
    if (!append_all_paths(&candidates, argv[i])) {
      printf(ANSI_YELLOW "Warning:" ANSI_RESET " Directory not found: %s\n",
             argv[i]);
    }
  }

  if (candidates.count == 0) {
    printf("No valid directories found to choose from.\n");
    return 1;
  }

  char selected_path[PATH_MAX];
  int succes = fzf(&candidates, selected_path, sizeof(selected_path));
  if (!succes || strcmp(selected_path,"") == 0)
    return 0;

  char session_name[PATH_MAX];
  char *file_name = strrchr(selected_path, '/');
  if (file_name) {
    snprintf(session_name, sizeof(session_name), "%s", file_name + 1);
    for (char *p = session_name; *p; ++p) {
      if (*p == '.') {
        *p = '_';
      }
    }
  } else {
    snprintf(session_name, sizeof(session_name), "%s", selected_path);
  }

  Nob_Cmd cmd = {0};
  chdir(selected_path);
  nob_cmd_append(&cmd, "zellij", "attach", session_name, "-c");
  if (!nob_cmd_run(&cmd)) {
    printf("Failed lanch zellij-session.");
    return 1;
  }

  nob_cmd_free(cmd);
  nob_sb_free(candidates);

  return 0;
}
