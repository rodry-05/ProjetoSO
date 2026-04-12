#include "utils.h"

int main(int argc, char *argv[]) {
    if (argc < 3) {
        printf("ERROR: insufficient arguments ...\n");
        return -1;
    }
    

    int parallel = atoi(argv[1]);
    char *policy = argv[2];
    
    struct timeval start_time, end_time;


    int number_of_running_commands = 0; // number of currently running commands
    int number_of_scheduled_commands = 0; // number of scheduled commands

    Message running_commands[256]; // array to store currently running commands
    Message scheduled_commands[256]; // array to store scheduled commands

    int shutdown_requested = 0;
    pid_t shutdown_pid = -1;


    // create FIFO 
    if (access("fifo_runner_to_controller", F_OK) != 0) {
        mkfifo("fifo_runner_to_controller", 0666);
    }

    // open FIFO
    int fd_requests = open("fifo_runner_to_controller", O_RDWR);
    if (fd_requests < 0) {
        printf("ERROR: failed to open FIFO\n");
        return -1;
    }

    Message request;
    while (1) {        
        if (read(fd_requests, &request, sizeof(Message)) > 0) {

            if (request.type == 1) { // execute command
                if (shutdown_requested) {
                    continue; 
                } else {
                    gettimeofday(&start_time, NULL);
                    scheduled_commands[number_of_scheduled_commands++] = request; // add the command to the scheduled commands list
                }
            } else if (request.type == 2) { // check status
                char fifo_controller_to_runner[256];
                sprintf(fifo_controller_to_runner, "fifo_controller_to_runner_%d", request.pid);
                
                int fd = open(fifo_controller_to_runner, O_WRONLY);
                if (fd < 0) {
                    printf("ERROR: failed to open %s\n", fifo_controller_to_runner);
                    continue;
                }

                char buffer[4096];
                int offset = 0;
                offset += sprintf(buffer + offset, "---\nExecuting\n");

                for (int i = 0; i < number_of_running_commands; i++) {
                    offset += sprintf(buffer + offset, "user-id %d - command-id %d\n", running_commands[i].user_id, running_commands[i].pid);
                }

                offset += sprintf(buffer + offset, "---\nScheduled\n");

                for (int i = 0; i < number_of_scheduled_commands; i++) {
                    offset += sprintf(buffer + offset, "user-id %d - command-id %d\n", scheduled_commands[i].user_id, scheduled_commands[i].pid);
                }

                // Send the status response to the runner
                write(fd, buffer, offset);
                close(fd);

            } else if (request.type == 3) { // shutdown
                if (!shutdown_requested) {
                    shutdown_requested = 1;
                    shutdown_pid = request.pid;
                }

            } else if (request.type == 4) { // command finished
                gettimeofday(&end_time, NULL);
                for (int i = 0; i < number_of_running_commands; i++) {
                    if (running_commands[i].pid == request.pid) {
                        for (int j = i; j < number_of_running_commands - 1; j++) {
                            running_commands[j] = running_commands[j + 1];  // shift the remaining commands to fill the gap
                        }
                        number_of_running_commands--;

                        double duration = (end_time.tv_sec - start_time.tv_sec) + (end_time.tv_usec - start_time.tv_usec) / 1000000.0;
                        int log_fd = open("../tmp/logs.txt", O_WRONLY | O_CREAT | O_APPEND, 0666);
                        if (log_fd < 0) {
                            printf("ERROR: failed to open/create log.txt\n");
                            return -1;
                        }
                        char buf[1024];
                        int len = sprintf(buf, "user_id: %d | command_id: %d | duration: %.06f\n", request.user_id, request.pid, duration);
                        write(log_fd, buf, len);
                        close(log_fd);


                        break;
                    }
                }
            }
            if (strcmp(policy, "fcfs") == 0) {
                while (number_of_running_commands < parallel && number_of_scheduled_commands > 0) {
                    Message next = scheduled_commands[0]; 
                    for (int i = 0; i < number_of_scheduled_commands - 1; i++) {
                        scheduled_commands[i] = scheduled_commands[i + 1];  // shift the remaining commands to fill the gap
                    }
                    number_of_scheduled_commands--;
                    running_commands[number_of_running_commands++] = next; // add the command to the running commands


                    pid_t pid = fork();
                    // 
                    if (pid < 0) {
                        printf("ERROR: failed to fork process\n");
                        return -1;
                    }

                    if (pid == 0) {
                        char fifo_controller_to_runner[256];
                        sprintf(fifo_controller_to_runner, "fifo_controller_to_runner_%d", next.pid);
                        int fd_confirmation = open(fifo_controller_to_runner, O_WRONLY);
                        if (fd_confirmation < 0) {
                            printf("ERROR: failed to open %s\n", fifo_controller_to_runner);
                            _exit(-1);
                        }
                        write(fd_confirmation, &next.pid, sizeof(pid_t)); // send the command_id as confirmation
                        close(fd_confirmation);
                        _exit(0); 
                    } else {
                        waitpid(pid, NULL, WNOHANG);
                    }

                }
            }
        }

        if (shutdown_requested == 1 && number_of_running_commands == 0 && number_of_scheduled_commands == 0) {
            char fifo_controller_to_runner[256];
            sprintf(fifo_controller_to_runner, "fifo_controller_to_runner_%d", shutdown_pid);
            
            int fd_shutdown_confirmation = open(fifo_controller_to_runner, O_WRONLY);
            if (fd_shutdown_confirmation < 0) {
                printf("ERROR: failed to open %s\n", fifo_controller_to_runner);
                return -1;
            }

            write(fd_shutdown_confirmation, &shutdown_pid, sizeof(pid_t)); // send the shutdown confirmation
            close(fd_shutdown_confirmation);
            break;
        }
    }

    unlink("fifo_runner_to_controller"); // remove the FIFO
    return 0;
}
