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

#define MAX_RUNNERS 10

typedef struct {
    int type; // operation types: 1 for execute, 2 for read, 3 for exit, 4 for status
    int user_id;
    pid_t pid; // command_id
    int n_args; // number of arguments in the command + command
    char command[32][256]; // buffer to store the command and its arguments
    struct timeval start_time; 
} Message;

int pick_next(Message *scheduled, int n_scheduled, int *user_executions) {
    int best = 0;
    for (int i = 1; i < n_scheduled; i++) {
        if (user_executions[scheduled[i].user_id] < user_executions[scheduled[best].user_id]) {
            best = i;
        }
    }
    return best;
}

#endif
