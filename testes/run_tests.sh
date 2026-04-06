
#!/bin/bash

CONTROLLER=./controller

# limpar logs
rm -f ../tmp/logs.txt

echo "=== TESTES DE ESCALONAMENTO ==="

for policy in fcfs rr
do
  for parallel in 1 2 4
  do
    echo ""
    echo "Policy=$policy | Parallel=$parallel"

    START=$(date +%s.%N)

    # simular múltiplos runners
    ./runner execute ./testes/fast &
    ./runner execute ./testes/slow &
    ./runner execute ./testes/medium &
    ./runner execute ./testes/fail &
    wait

    END=$(date +%s.%N)
    TIME=$(echo "$END - $START" | bc)

    echo "Tempo total: $TIME segundos"
  done
done