#!/bin/bash

# ============================================================
# CVDW-CLI - Script de Execução com Proteção contra Concorrência
# ============================================================

LOCKFILE="/tmp/cvdw-cli.lock"
LOGFILE="/tmp/cvdw-cli-execution.log"

# Verifica se já existe uma execução em andamento
if [ -f "$LOCKFILE" ]; then
    LOCK_PID=$(cat "$LOCKFILE")
    if kill -0 "$LOCK_PID" 2>/dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - CVDW-CLI já está em execução (PID: $LOCK_PID). Ignorando."
        exit 0
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Lock stale encontrado. Removendo..."
        rm -f "$LOCKFILE"
    fi
fi

# Cria o lock file com o PID atual
echo $$ > "$LOCKFILE"

# Garante que o lock será removido ao sair (mesmo com erro)
cleanup() {
    rm -f "$LOCKFILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Lock removido. Execução finalizada."
}
trap cleanup EXIT

echo "$(date '+%Y-%m-%d %H:%M:%S') - Iniciando execução do CVDW-CLI (PID: $$)"

# Executa redirecionando output para arquivo (evita flood de logs no Railway)
bash -ic "cvdw executar all -qtd 500" >> "$LOGFILE" 2>&1
EXIT_CODE=$?

# Exibe as últimas linhas do log no stdout para monitoramento
echo "--- Últimas 50 linhas do log ---"
tail -50 "$LOGFILE"

# Rotaciona o log se passar de 5MB
if [ -f "$LOGFILE" ]; then
    LOG_SIZE=$(stat -c%s "$LOGFILE" 2>/dev/null || stat -f%z "$LOGFILE" 2>/dev/null || echo 0)
    if [ "$LOG_SIZE" -gt 5242880 ]; then
        mv "$LOGFILE" "${LOGFILE}.old"
    fi
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - CVDW-CLI finalizado com código: $EXIT_CODE"
exit $EXIT_CODE
