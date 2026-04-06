#include <stdlib.h>
#include <unistd.h>
#include <time.h>

int main() {
    srand(time(NULL) ^ getpid());

    int t = rand() % 3; // 0–2 segundos
    sleep(t);

    return rand() % 2; // sucesso ou falha
}