CC = gcc
CFLAGS = -Wall -g -I.
LDFLAGS = 

# Declara que os targets não corresponde a ficheiros reais
.PHONY: all controller runner folders clean

# Lista de executáveis final
all: folders controller runner

controller: bin/controller

runner: bin/runner

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

# Usado para limpar os fifos criados durante a execução do programa
clean:             
	rm -rf obj/* tmp/* bin/*
	rm -rf obj tmp bin
	rm -f fifo_*