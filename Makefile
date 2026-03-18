CC = gcc
CFLAGS = -Wall -g -I.
LDFLAGS = 

# Lista de executáveis final
all: folders mycontroller myrunner

mycontroller: bin/controller

myrunner: bin/runner

# Criação das pastas necessárias
folders:
	@mkdir -p obj bin tmp

# Linkagem do Controller
bin/controller: obj/controller.o
	$(CC) $(LDFLAGS) $^ -o $@

# Linkagem do Runner
bin/runner: obj/runner.o
	$(CC) $(LDFLAGS) $^ -o $@

# Regra genérica para compilar objetos (.o) a partir dos fontes (.c) na raiz
obj/%.o: %.c 
	$(CC) $(CFLAGS) -c $< -o $@

# Limpeza de ficheiros temporários
clean:
	rm -rf obj/* tmp/* bin/*
	rm -rf obj tmp bin
	rm -f fifo_*