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
        char **n_argv = argv + 3; // new char *argv[] with arguments only 
        int n_argc = argc - 3; // new argc with number of arguments

         for (int i = 0; i < n_argc; i++) {
            printf("Argument %d: %s\n", i, n_argv[i]);
        }

        Message request;
        request.pid = getpid(); // use runner's PID as command_id
        request.user_id = user_id;
        request.type = 1; // type 1 for execute command
        strcpy(request.command, n_argv[0]); // copy the command to the request

        char fifo_responses[1024];
        sprintf(fifo_responses, "fifo_responses_%d", request.pid); // create unique FIFO name for responses
        mkfifo(fifo_responses, 0666); // create the FIFO for responses

        int fd_requests = open("fifo_requests", O_WRONLY);
        if (fd_requests < 0) {
            printf("ERROR: failed to open fifo_requests\n");
            return -1;
        }
        write(fd_requests, &request, sizeof(Message)); // send the request to the controller
        close(fd_requests); // close the FIFO after writing

        printf("[runner] command %d submited\n", request.pid);

        int fd_responses = open(fifo_responses, O_RDONLY); // open the FIFO for reading responses
        if (fd_responses < 0) {
            printf("ERROR: failed to open %s\n", fifo_responses);
            return -1;
        }
        Message response;
        read(fd_responses, &response, sizeof(Message)); // read the response from the controller
        close(fd_responses); // close the FIFO after reading
        unlink(fifo_responses); // remove the FIFO after use


        printf("[runner] executing command %d...\n", request.pid);
        pid_t pid = fork();
        if (pid < 0) {
            printf("ERROR: failed to fork process\n");
            return -1;
        }

        if (pid == 0) { // child process to execute the command
            execvp(n_argv[0], n_argv); // execute the command with arguments
            printf("ERROR: failed to execute command\n");
            return -1;
        } else { // parent process waits for the child to finish
            waitpid(pid, NULL, 0);
            printf("[runner] command %d finished\n", request.pid);

            // notifica o controller que o comando terminou
            Message done;
            done.pid = request.pid;
            done.user_id = user_id;
            done.type = 4; // command finished

            int fd_req = open("fifo_requests", O_WRONLY);
            write(fd_req, &done, sizeof(Message));
            close(fd_req);

        }




    } else if (strcmp(argv[1], "-c") == 0) { // ./runner -c
 
        
    } else if (strcmp(argv[1], "-s") == 0) { // ./runner -s


    } else {
        printf("ERROR: invalid arguments!\n");
        return -1;
    }



}
