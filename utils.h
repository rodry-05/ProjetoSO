#ifndef UTILS_H
#define UTILS_H

#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <sys/time.h>
#include <sys/stat.h>

typedef struct {
    int type; // operation types: 1 for execute, 2 for read, 3 for exit, 4 for status
    int user_id;
    pid_t pid; // command_id
    int n_args; // number of arguments in the command + command
    char command[32][256]; // buffer to store the command and its arguments
} Message;

#endif
