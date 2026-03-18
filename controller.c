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
            // DELETE

            if (request.type == 1) { // execute command
                scheduled_commands[number_of_scheduled_commands++] = request; // add the command to the scheduled commands list

            } else if (request.type == 2) { // check status
            } else if (request.type == 3) { // shoutdown
            } else if (request.type == 4) { // command finished
                for (int i = 0; i < number_of_running_commands; i++) {
                    if (running_commands[i].pid == request.pid) {
                        for (int j = i; j < number_of_running_commands - 1; j++) {
                            running_commands[j] = running_commands[j + 1];  // shift the remaining commands to fill the gap
                        }
                        number_of_running_commands--;
                        break;
                    }
                }
            }

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
    

}
