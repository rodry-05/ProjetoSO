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
    pid_t pid; // command_id
    char command[1024];
    int user_id;
    int type; // operation types: 1 for execute, 2 for read, 3 for exit, 4 for status
} Message;

#endif
