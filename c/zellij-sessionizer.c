#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <limits.h>

#define NOB_IMPLEMENTATION
#define NOB_EXPERIMENTAL_DELETE_OLD
#define NOB_WARN_DEPRECATED
#include "nob.h"

#define ANSI_RESET "\x1B[0m"
#define ANSI_RED "\x1B[31m"
#define ANSI_GREEN "\x1B[32m"
#define ANSI_YELLOW "\x1B[33m"

#define CONFIG_PATH_HOME ".config/zellij-sessionizer/dirs"

bool is_dir(const char *path) {
  struct stat statbuf;
  return (stat(path, &statbuf) == 0 && S_ISDIR(statbuf.st_mode));
}

bool dir_in_list(Nob_String_Builder *list, const char *path) {
  if (!list->items || list->count == 0) return false;
  
  char *p = list->items;
  while (*p) {
    char *newline = strchr(p, '\n');
    if (newline) *newline = '\0';
    if (strcmp(p, path) == 0) {
      if (newline) *newline = '\n';
      return true;
    }
    if (newline) *newline = '\n';
    p = newline ? newline + 1 : p + strlen(p);
    if (*p == '\0') break;
  }
  return false;
}

void add_dir(Nob_String_Builder *list, const char *path, bool verbose) {
  char temp_path[PATH_MAX];
  strncpy(temp_path, path, PATH_MAX - 1);
  temp_path[PATH_MAX - 1] = '\0';

  size_t len = strlen(temp_path);
  if (len > 0 && temp_path[len - 1] == '/') {
    temp_path[len - 1] = '\0';
  }

  if (!is_dir(temp_path)) {
    if (verbose)
      printf(ANSI_YELLOW "Warning:" ANSI_RESET " Directory not found: %s\n",
             temp_path);
    return;
  }

  if (!dir_in_list(list, temp_path)) {
    nob_sb_appendf(list, "%s\n", temp_path);
  }
}

void add_subdirs(Nob_String_Builder *list, const char *parent, bool verbose) {
  DIR *dir = opendir(parent);
  if (!dir) {
    if (verbose)
      printf(ANSI_YELLOW "Warning:" ANSI_RESET " Cannot read directory: %s\n",
             parent);
    return;
  }

  struct dirent *entry;
  while ((entry = readdir(dir)) != NULL) {
    if (entry->d_name[0] == '.') continue;

    char subpath[PATH_MAX];
    snprintf(subpath, sizeof(subpath), "%s/%s", parent, entry->d_name);

    if (is_dir(subpath)) {
      add_dir(list, subpath, verbose);
    }
  }

  closedir(dir);
}

void process_config_line(Nob_String_Builder *list, char *line, bool verbose);

const char *get_home(void) {
  static char home[PATH_MAX];
  if (home[0] == '\0') {
    const char *h = getenv("HOME");
    if (h) {
      strncpy(home, h, PATH_MAX - 1);
      home[PATH_MAX - 1] = '\0';
    }
  }
  return home[0] ? home : NULL;
}

void expand_path(const char *input, char *output, size_t out_size) {
  const char *home = get_home();
  
  if (home && input[0] == '~') {
    if (input[1] == '/' || input[1] == '\0') {
      snprintf(output, out_size, "%s%s", home, input + 1);
      return;
    }
  }
  
  if (input[0] != '/' && home) {
    snprintf(output, out_size, "%s/%s", home, input);
    return;
  }
  
  strncpy(output, input, out_size - 1);
  output[out_size - 1] = '\0';
}

void process_config_line(Nob_String_Builder *list, char *line, bool verbose) {
  size_t len = strlen(line);
  while (len > 0 && (line[len - 1] == '\n' || line[len - 1] == '\r')) {
    line[--len] = '\0';
  }

  while (*line == ' ' || *line == '\t') line++;
  if (*line == '\0' || *line == '#') return;

  size_t path_len = strlen(line);
  bool has_star = (path_len >= 2 && line[path_len - 1] == '*' && line[path_len - 2] == '/');

  char expanded[PATH_MAX];
  if (has_star) {
    line[path_len - 2] = '\0';
    expand_path(line, expanded, sizeof(expanded));
    add_subdirs(list, expanded, verbose);
  } else {
    expand_path(line, expanded, sizeof(expanded));
    add_dir(list, expanded, verbose);
  }
}

bool load_config(Nob_String_Builder *list, bool verbose) {
  const char *home = getenv("HOME");
  if (!home) {
    if (verbose) printf(ANSI_YELLOW "Warning:" ANSI_RESET " HOME not set\n");
    return false;
  }

  char config_path[PATH_MAX];
  snprintf(config_path, sizeof(config_path), "%s/%s", home, CONFIG_PATH_HOME);

  FILE *f = fopen(config_path, "r");
  if (!f) {
    if (verbose) printf(ANSI_YELLOW "Warning:" ANSI_RESET " Config file not found: %s\n", config_path);
    return false;
  }

  char line[4096];
  while (fgets(line, sizeof(line), f)) {
    process_config_line(list, line, verbose);
  }

  fclose(f);
  return true;
}

int fzf(const Nob_String_Builder *const list, char *const out_result,
        const int result_length, const char *query) {
  Nob_String_Builder fzf_cmd = {0};
  
  if (query && query[0] != '\0') {
    nob_sb_appendf(&fzf_cmd, "printf '%%s\\n' '%s' | fzf -q '%s' --select-1 --exit-0", list->items, query);
  } else {
    nob_sb_appendf(&fzf_cmd, "printf '%%s\\n' '%s' | fzf", list->items);
  }

  FILE *fzf_handle = popen(fzf_cmd.items, "r");
  if (!fzf_handle) {
    printf(ANSI_RED "Error:" ANSI_RESET " Failed to execute fzf\n");
    return 0;
  }

  if (fgets(out_result, result_length, fzf_handle))
    out_result[strcspn(out_result, "\n")] = 0;

  nob_sb_free(fzf_cmd);
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

  Nob_String_Builder candidates = {0};

  bool verbose = false;
  for (int i = 1; i < argc; i++) {
    if (!strcmp(argv[i], "-v") || !strcmp(argv[i], "--verbose")) {
      verbose = true;
    }
  }

  load_config(&candidates, verbose);

  int dash_dash_idx = -1;
  for (int i = 1; i < argc; i++) {
    if (!strcmp(argv[i], "--")) {
      dash_dash_idx = i;
      break;
    }
  }

  if (dash_dash_idx == -1) {
    for (int i = 1; i < argc; i++) {
      if (strcmp(argv[i], "-v") && strcmp(argv[i], "--verbose")) {
        char expanded[PATH_MAX];
        expand_path(argv[i], expanded, sizeof(expanded));
        add_dir(&candidates, expanded, verbose);
      }
    }
  } else {
    for (int i = 1; i < dash_dash_idx; i++) {
      if (strcmp(argv[i], "-v") && strcmp(argv[i], "--verbose")) {
        char expanded[PATH_MAX];
        expand_path(argv[i], expanded, sizeof(expanded));
        add_dir(&candidates, expanded, verbose);
      }
    }
  }

  if (candidates.count == 0) {
    printf("No valid directories found to choose from.\n");
    printf("Usage: ./zellij-sessionizer [dirs...] [-- query]\n"
           "  With no args: use config file (~/.config/zellij-sessionizer/dirs)\n"
           "  Config: one directory per line, # comments, /* for subdirs\n");
    return 1;
  }

  char selected_path[PATH_MAX];
  const char *query = NULL;
  if (dash_dash_idx != -1 && dash_dash_idx + 1 < argc) {
    query = argv[dash_dash_idx + 1];
  }

  int succes = fzf(&candidates, selected_path, sizeof(selected_path), query);
  if (!succes || strcmp(selected_path, "") == 0)
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
  int _ = chdir(selected_path);
  (void)_;
  nob_cmd_append(&cmd, "zellij", "attach", session_name, "-c");
  if (!nob_cmd_run(&cmd)) {
    printf("Failed lanch zellij-session.");
    return 1;
  }

  nob_cmd_free(cmd);
  nob_sb_free(candidates);

  return 0;
}
