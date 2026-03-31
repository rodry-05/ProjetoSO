#include "utils.h"

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("ERROR: insufficient arguments ...\n");
        return -1;
    }


    if (strcmp(argv[1], "-e") == 0) { // ./runner -e <user_id> <command> <args...>
        if (argc < 4) {
            printf("ERROR: insufficient arguments for ./runner -e\n");
            return -1;
        }

        int user_id = atoi(argv[2]); // string to int conversion of user_id
        char **n_argv = argv + 3; // new char *argv[] with command + arguments only 
        int n_argc = argc - 3; // new argc with number of command + arguments

        
        // Preparing the request message to send to the controller
        Message permission_request;
        permission_request.type = 1; // type 1 for execute command
        permission_request.user_id = user_id;
        permission_request.pid = getpid(); // use runner's PID as command_id
        permission_request.n_args = n_argc;
        for (int i = 0; i < n_argc; i++) {
            strcpy(permission_request.command[i], n_argv[i]); // copy the command and arguments
        }

        // Prepare the FIFO for receiving the controller's confirmation
        char fifo_controller_to_runner[256];
        sprintf(fifo_controller_to_runner, "fifo_controller_to_runner_%d", permission_request.pid); // create a unique FIFO name for this runner
        mkfifo(fifo_controller_to_runner, 0666); // create the FIFO



        // Send the permission request to the controller
        int fd_permission_request = open("fifo_runner_to_controller", O_WRONLY);
        if (fd_permission_request < 0) {
            printf("ERROR: failed to open fifo_runner_to_controller\n");
            return -1;
        }
        write(fd_permission_request, &permission_request, sizeof(Message)); // send the permission request
        close(fd_permission_request); // close the FIFO

        printf("[runner] command %d submited\n", permission_request.pid);
        // Wait for the controller's permission

        
        // Wait for the controller's permission
        int fd_confirmation = open(fifo_controller_to_runner, O_RDONLY); 
        if (fd_confirmation < 0) {
            printf("ERROR: failed to open %s\n", fifo_controller_to_runner);
            return -1;
        }

        pid_t command;
        read(fd_confirmation, &command, sizeof(pid_t)); 
        close(fd_confirmation);
        unlink(fifo_controller_to_runner); // remove the FIFO after use
        // Permission granted

        
        
        // Execute the command
        printf("[runner] executing command %d...\n", command);
        
        // Fork, execute the command in the child process, and wait for it to finish in the parent process
        pid_t pid = fork();
        if (pid < 0) {
            printf("ERROR: failed to fork process\n");
            return -1;
        }

        if (pid == 0) {
            execvp(n_argv[0], n_argv); // execute the command with arguments
            printf("ERROR: failed to execute command\n");
            return -1;
        } else { 
            waitpid(pid, NULL, 0);
            printf("[runner] command %d finished\n", command);

            // Notify the controller that the command has finished
            Message done;
            done.type = 4;
            done.user_id = user_id;
            done.pid = command; 

            // Send the notification to the controller
            int fd_done = open("fifo_runner_to_controller", O_WRONLY);
            if (fd_done < 0) {
                printf("ERROR: failed to open fifo_runner_to_controller\n");
                return -1;
            }
            write(fd_done, &done, sizeof(Message));
            close(fd_done); 
            
        }


    } else if (strcmp(argv[1], "-c") == 0) { // ./runner -c
        if (argc != 2) {
            printf("ERROR: invalid arguments for ./runner -c\n");
            return -1;
        }

        Message status_request;
        status_request.type = 2; // type 2 for status request
        status_request.pid = getpid(); // use runner's PID to identify the request
        
        char fifo_controller_to_runner[256];
        sprintf(fifo_controller_to_runner, "fifo_controller_to_runner_%d", status_request.pid); // create a unique FIFO name for this runner
        mkfifo(fifo_controller_to_runner, 0666); // create a unique FIFO for this runner
        

        // Send the status request to the controller
        int fd_status_request = open("fifo_runner_to_controller", O_WRONLY);
        if (fd_status_request < 0) {
            printf("ERROR: failed to open fifo_runner_to_controller\n");
            return -1;
        }
        write(fd_status_request, &status_request, sizeof(Message)); // send the status request
        close(fd_status_request); // close the FIFO

        int fd_status_response = open(fifo_controller_to_runner, O_RDONLY);
        if (fd_status_response < 0) {
            printf("ERROR: failed to open %s\n", fifo_controller_to_runner);
            return -1;
        }

        // Read the status response from the controller and print it
        char buffer[1024];
        int bytes_read;
        while((bytes_read = read(fd_status_response, buffer, sizeof(buffer) - 1)) >  0) {
            buffer[bytes_read] = '\0'; // null-terminate the string
            printf("%s", buffer); // print the status response
        }
        close(fd_status_response); // close the FIFO
        unlink(fifo_controller_to_runner); // remove the FIFO after use



    } else if (strcmp(argv[1], "-s") == 0) { // ./runner -s

        Message shutdown_request;
        shutdown_request.type = 3; // type 3 for shutdown request
        shutdown_request.pid = getpid(); // use runner's PID to identify the request

        // 
        char fifo_controller_to_runner[256];
        sprintf(fifo_controller_to_runner, "fifo_controller_to_runner_%d", shutdown_request.pid); // create a unique FIFO name for this runner
        mkfifo(fifo_controller_to_runner, 0666); // create a unique FIFO for this runner    

        // Send the shutdown request to the controller
        int fd_shutdown_request = open("fifo_runner_to_controller", O_WRONLY);
        if (fd_shutdown_request < 0) {
            printf("ERROR: failed to open fifo_runner_to_controller\n");
            return -1;
        }
        write(fd_shutdown_request, &shutdown_request, sizeof(Message)); // send the shutdown request
        close(fd_shutdown_request); // close the FIFO

        printf("[runner] sent shutdown notification\n");
        // Wait the shutdown confirmation from the controller


        printf("[runner] waiting for controller to shutdown...\n");
        // Wait the shutdown confirmation from the controller
        int fd_confirmation = open(fifo_controller_to_runner, O_RDONLY);
        if (fd_confirmation < 0) {
            printf("ERROR: failed to open %s\n", fifo_controller_to_runner);
            return -1;
        }
        
        pid_t confirmation;
        read(fd_confirmation, &confirmation, sizeof(pid_t));
        close(fd_confirmation);
        unlink(fifo_controller_to_runner); // remove the FIFO after use
        // Shutdown confirmed

        printf("[runner] controller exited.\n");

    } else {
        printf("ERROR: invalid arguments!\n");
        return -1;
    }


    return 0;
}
