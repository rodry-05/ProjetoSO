#include "utils.h"

int main(int argc, char *argv[]) {
    if (argc < 3) {
        printf("ERROR: insufficient arguments ...\n");
        return -1;
    }

    int parallel = atoi(argv[1]);
    char *policy = argv[2];
    
    struct timeval start_time, end_time;


    int running_commands = 0;
    int scheduled_commands = 0;

    Message running_cmd[5]; // array to store currently running commands
    Message scheduled_cmd[256]; // array to store scheduled commands


    // create FIFOs
    if (access("fifo_requests", F_OK) != 0) {
        mkfifo("fifo_requests", 0666);
    }
    if (access("fifo_responses", F_OK) != 0) {
        mkfifo("fifo_responses", 0666);
    }

    // open FIFOs
    int fd_requests = open("fifo_requests", O_RDWR);
    int fd_responses = open("fifo_responses", O_RDWR);

    if (fd_requests < 0 || fd_responses < 0) {
        printf("ERROR: failed to open FIFOs\n");
        return -1;
    }

    Message request;
    while (1) {
        waitpid(-1, NULL, WNOHANG); // reap any finished child processes
        
        if (read(fd_requests, &request, sizeof(Message)) > 0) {
            printf("request type=%d pid=%d\n", request.type, request.pid);

            int fd_pipe[2];
            if (pipe(fd_pipe) != 0) {
                printf("ERROR: failed to create pipe\n");
                return -1;
            } 

            pid_t pid = fork();

            if (pid < 0) {
                printf("ERROR: failed to fork process\n");
                continue;
            }

            if (pid == 0) { // child process
                close(fd_pipe[0]); 

                if (request.type == 1) { // execute command
                    scheduled_cmd[scheduled_commands++] = request; // add command to scheduling queue
                    /*if (running_commands < parallel) {
                        scheduled_commands--;
                        running_commands++;

                        char fifo_responses[1024];
                        sprintf(fifo_responses, "fifo_responses_%d", request.pid);
                        int fd_response = open(fifo_responses, O_WRONLY);
                        Message response;
                        response.pid = request.pid;
                        write(fd_response, &response, sizeof(Message));
                        close(fd_response);
                    
                    } else {
                        // add command to scheduling queue
                        scheduled_commands++;
                    }*/
                } else if (request.type == 2) { // check status

                } else if (request.type == 3) { // shoutdown

                } else if (request.type == 4) { // command finished
                    for (int i = 0; i < running_commands; i++) {
                        if (running_cmd[i].pid == request.pid) {
                            // remove command from running array
                            for (int j = i; j < running_commands - 1; j++) {
                                running_cmd[j] = running_cmd[j + 1];
                            }
                            running_commands--;
                            break;
                        }
                    }
                }

                while (running_commands < parallel && scheduled_commands > 0) {
                    Message next_command = scheduled_cmd[0]; // get next command from scheduling queue
                    for (int i = 0; i < scheduled_commands - 1; i++) {
                        scheduled_cmd[i] = scheduled_cmd[i + 1]; // shift remaining commands in scheduling queue
                    }
                    scheduled_commands--;
                    running_cmd[running_commands++] = next_command; // add command to running array

                    char fifo_responses[1024];
                    sprintf(fifo_responses, "fifo_responses_%d", next_command.pid);
                    int fd_response = open(fifo_responses, O_WRONLY);
                    Message response;
                    response.pid = next_command.pid;
                    write(fd_response, &response, sizeof(Message));
                    close(fd_response);
                }

                write(fd_pipe[1], &running_commands, sizeof(int));
                write(fd_pipe[1], &scheduled_commands, sizeof(int));
                _exit(0);
            } else if (pid > 0) { // parent process
                close(fd_pipe[1]);
                read(fd_pipe[0], &running_commands, sizeof(int));
                read(fd_pipe[0], &scheduled_commands, sizeof(int));
                close(fd_pipe[0]);
                printf("[controller] running_commands=%d scheduled_commands=%d\n", running_commands, scheduled_commands); // debug
            }   
        }
    }
    

}
