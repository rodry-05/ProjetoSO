#include "utils.h"

#define MAX_ARGUMENTS 32
#define MAX_SEGMENTS 16
typedef struct {
    char *argv[MAX_ARGUMENTS + 1];
    int   argc;
    char *stdin_file;   // < file
    char *stdout_file;  // > file
    char *stderr_file;  // 2> file
} Segment;

int parsing(char **tokens, int n_tokens, Segment *segs) {
    int n_segs = 0;
    segs[0] = (Segment) {
        .argc = 0,
        .stdin_file = NULL,
        .stdout_file = NULL,
        .stderr_file = NULL
    };

    for (int i = 0; i < n_tokens; i++) {
        int n_args = segs[n_segs].argc;  // number of arguments on this segment
        if (strcmp(tokens[i], "|") == 0) {
            // Terminate current segment and start a new one
            segs[n_segs].argv[n_args] = NULL;
            n_segs++;
            segs[n_segs] = (Segment) {
                .argc = 0,
                .stdin_file = NULL,
                .stdout_file = NULL,
                .stderr_file = NULL
            };

        } else if (strcmp(tokens[i], "<") == 0 && i + 1 < n_tokens) {
            segs[n_segs].stdin_file = tokens[++i];  // redirect stdin from file


        } else if (strcmp(tokens[i], ">") == 0 && i + 1 < n_tokens) {
            segs[n_segs].stdout_file = tokens[++i]; // redirect stdout to file


        } else if (strcmp(tokens[i], "2>") == 0 && i + 1 < n_tokens) {
            segs[n_segs].stderr_file = tokens[++i]; // redirect stderr to file

        } else {
            segs[n_segs].argv[segs[n_segs].argc++] = tokens[i]; // regular argument
        }
    }

    // null-terminate the argv of the last segment
    segs[n_segs].argv[segs[n_segs].argc] = NULL;
    return n_segs + 1;
}


void execute_command_pipeline(Segment *segs, int n_segs) {
    int pipes[MAX_SEGMENTS - 1][2];
    pid_t pids[MAX_SEGMENTS];

    // create one pipe between each pair of adjacent segments
    for (int i = 0; i < n_segs - 1; i++) {
        if (pipe(pipes[i]) < 0) {
            printf ("ERROR: failed to create pipe\n");
            return;
        }
    }

    // fork one child per segment
    for (int i = 0; i < n_segs; i++) {
        pids[i] = fork();

        if (pids[i] < 0) {
            printf("ERROR: failed to fork process\n");
        }

        if (pids[i] == 0) { // child process

            // redirect stdin: read from previous pipe or from file
            if (i > 0 && segs[i].stdin_file == NULL) {
                dup2(pipes[i-1][0], 0);

            } else if (segs[i].stdin_file != NULL) {
                int fd = open(segs[i].stdin_file, O_RDONLY);

                if (fd < 0) {
                    printf("ERROR: failed to open stdin file\n");
                    return;
                }

                dup2(fd, 0);
                close(fd);
            }

            // redirect stdout: write to next pipe or to file
            if (i < n_segs - 1 && segs[i].stdout_file == NULL) {
                dup2(pipes[i][1], 1);

            } else if (segs[i].stdout_file != NULL) {
                int fd = open(segs[i].stdout_file, O_WRONLY | O_CREAT | O_TRUNC, 0666);

                if (fd < 0) {
                    printf("ERROR: failed to open/create stdout file\n");
                    return;
                }

                dup2(fd, 1);
                close(fd);
            }

            // redirect stderr to file if specified
            if (segs[i].stderr_file != NULL) {
                int fd = open(segs[i].stderr_file, O_WRONLY | O_CREAT | O_TRUNC, 0666);

                if (fd < 0) {
                    printf("ERROR: failed to open/create stderr file\n");
                }

                dup2(fd, 2);
                close(fd);
            }

            // close all pipe ends in the child — only the duped fds are needed
            for (int j = 0; j < n_segs - 1; j++) {
                close(pipes[j][0]);
                close(pipes[j][1]);
            }

            execvp(segs[i].argv[0], segs[i].argv);
            printf("ERROR: failed to execute command\n");
            _exit(1);
        }
    }

    // parent closes all pipe ends so children can detect EOF
    for (int i = 0; i < n_segs - 1; i++) {
        close(pipes[i][0]);
        close(pipes[i][1]);
    }

    // wait for all children to finish
    for (int i = 0; i < n_segs; i++) {
        waitpid(pids[i], NULL, 0);
    }
}


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
        
        // Parse the command string (argv[3]) into tokens
        char buf[4096];
        strncpy(buf, argv[3], sizeof(buf) - 1);
        buf[sizeof(buf) - 1] = '\0';

        char *tokens[MAX_ARGUMENTS + 1];
        int n_tokens = 0; 
        char *token = strtok(buf, " ");
        while (token && n_tokens < MAX_ARGUMENTS) {
            tokens[n_tokens++] = token;
            token = strtok(NULL, " ");
        }
        tokens[n_tokens] = NULL;

        if (n_tokens == 0) {
            printf("ERROR: empty command\n");
            return -1;
        }
        
        // Preparing the request message to send to the controller
        Message permission_request;
        permission_request.type = 1; // type 1 for execute command
        permission_request.user_id = user_id;
        permission_request.pid = getpid(); // use runner's PID as command_id
        permission_request.n_args = n_tokens;
        for (int i = 0; i < n_tokens; i++) {
            strcpy(permission_request.command[i], tokens[i]); // copy the command and arguments
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

        char buffer_aux[1024];
        sprintf(buffer_aux, "[runner] command %d submitted\n", permission_request.pid);
        write(1, buffer_aux, strlen(buffer_aux)); // print the submission message to stdout
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
        sprintf(buffer_aux, "[runner] executing command %d...\n", command);
        write(1, buffer_aux, strlen(buffer_aux)); // print the execution message to stdout
        
        // Parse the command into segments and execute the pipeline
        Segment segs[MAX_SEGMENTS];
        int n_segs = parsing(tokens, n_tokens, segs);
        execute_command_pipeline(segs, n_segs);

        sprintf(buffer_aux, "[runner] command %d finished\n", command);
            
        write(1, buffer_aux, strlen(buffer_aux)); // print the finished message to stdout


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
            write(1, buffer, strlen(buffer)); // print the status response
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

        char buffer_aux[1024];
        sprintf(buffer_aux, "[runner] sent shutdown notification\n");
        write(1, buffer_aux, strlen(buffer_aux)); // print the shutdown notification message to stdout
        // Wait the shutdown confirmation from the controller

        sprintf(buffer_aux, "[runner] waiting for controller to shutdown...\n");
        write(1, buffer_aux, strlen(buffer_aux)); // print the waiting message to stdout
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

        sprintf(buffer_aux, "[runner] controller exited.\n");
        write(1, buffer_aux, strlen(buffer_aux)); // print the controller exit message to stdout

    } else {
        printf("ERROR: invalid arguments!\n");
        return -1;
    }


    return 0;
}
