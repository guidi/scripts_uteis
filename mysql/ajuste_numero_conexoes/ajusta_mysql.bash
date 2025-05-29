#!/bin/bash

# Este script calcula os valores ideais de:
# - max_connections
# - innodb_buffer_pool_size
#
# Baseado na memória RAM do sistema e no perfil de uso:
# performance | balanceado | escala
#
# Reserva 10% da RAM total para o sistema operacional, com no mínimo 512MB.
#
# Fonte da fórmula base: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Limits.html#RDS_Limits.MaxConnections
# Fórmula da AWS: max_connections = DBInstanceClassMemory / 12582880

# ===================== CONFIGURAÇÃO =====================
PERFIL="balanceado"  # valores possíveis: performance, balanceado, escala
MYCNF_PATH="/etc/mysql/my.cnf"
LOG_PATH="/var/log/mysql_config_tuning.log"
BACKUP_PATH="/etc/mysql/my.cnf.bkp.$(date +%Y%m%d%H%M%S)"
RESERVA_MINIMA_BYTES=$((512 * 1024 * 1024))  # 512MB
RESERVA_PERCENTUAL=0.10
# ========================================================

# Define timezone para o log (GMT-3)
export TZ=America/Sao_Paulo
TIMESTAMP=$(date "+%d/%m/%Y %H:%M:%S GMT-3")

# Calcula RAM total
MEM_TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEM_TOTAL_BYTES=$((MEM_TOTAL_KB * 1024))
MEM_TOTAL_MB=$((MEM_TOTAL_KB / 1024))

echo "Memoria total detectada: ${MEM_TOTAL_MB} MB"
echo "Aplicando perfil de uso: $PERFIL"

# Define percentual de uso conforme perfil
case "$PERFIL" in
  performance)
    PERCENT_BUFFER=0.75
    PERCENT_CONN=0.25
    ;;
  balanceado)
    PERCENT_BUFFER=0.625
    PERCENT_CONN=0.375
    ;;
  escala)
    PERCENT_BUFFER=0.50
    PERCENT_CONN=0.50
    ;;
  *)
    echo "Perfil invalido: $PERFIL"
    exit 1
    ;;
esac

# Calcula reserva para o SO
RESERVA_SO_CALCULADA=$(printf "%.0f" $(echo "$MEM_TOTAL_BYTES * $RESERVA_PERCENTUAL" | bc -l))
if [ "$RESERVA_SO_CALCULADA" -lt "$RESERVA_MINIMA_BYTES" ]; then
  RESERVA_SO=$RESERVA_MINIMA_BYTES
else
  RESERVA_SO=$RESERVA_SO_CALCULADA
fi

MEM_USAVEL_BYTES=$((MEM_TOTAL_BYTES - RESERVA_SO))

if [ "$MEM_USAVEL_BYTES" -le 0 ]; then
  echo "Erro: Memoria insuficiente apos reservar espaco para o sistema operacional."
  exit 1
fi

# Calcula valores finais
BUFFER_POOL_BYTES=$(printf "%.0f" $(echo "$MEM_USAVEL_BYTES * $PERCENT_BUFFER" | bc -l))
RAM_PARA_CONEXOES=$(printf "%.0f" $(echo "$MEM_USAVEL_BYTES * $PERCENT_CONN" | bc -l))
MAX_CONNECTIONS=$(printf "%.0f" $(echo "$RAM_PARA_CONEXOES / 12582880" | bc -l))

echo "Memoria reservada para o SO: $(($RESERVA_SO / 1024 / 1024)) MB"
echo "Buffer pool reservado: $(($BUFFER_POOL_BYTES / 1024 / 1024)) MB"
echo "Memoria para conexoes: $(($RAM_PARA_CONEXOES / 1024 / 1024)) MB"
echo "max_connections calculado: $MAX_CONNECTIONS"
echo

# Backup do arquivo atual
cp "$MYCNF_PATH" "$BACKUP_PATH"
echo "Backup do arquivo atual salvo em: $BACKUP_PATH"

# Remove entradas antigas (se existirem)
sed -i '/^\s*max_connections\s*=/d' "$MYCNF_PATH"
sed -i '/^\s*innodb_buffer_pool_size\s*=/d' "$MYCNF_PATH"
sed -i '/^\s*wait_timeout\s*=/d' "$MYCNF_PATH"
sed -i '/^\s*interactive_timeout\s*=/d' "$MYCNF_PATH"

# Garante que [mysqld] exista
if ! grep -q "^\[mysqld\]" "$MYCNF_PATH"; then
  echo "[mysqld]" >> "$MYCNF_PATH"
fi

# Aplica configuracoes novas
awk -v mc="$MAX_CONNECTIONS" -v bp="$BUFFER_POOL_BYTES" '
  BEGIN { added=0 }
  /^\[mysqld\]/ {
    print
    print "max_connections = " mc
    print "innodb_buffer_pool_size = " bp
    print "wait_timeout = 180"
    print "interactive_timeout = 180"
    added=1
    next
  }
  { print }
  END {
    if (added == 0) {
      print "[mysqld]"
      print "max_connections = " mc
      print "innodb_buffer_pool_size = " bp
      print "wait_timeout = 180"
      print "interactive_timeout = 180"
    }
  }
' "$BACKUP_PATH" > "$MYCNF_PATH"

echo "Configuracoes aplicadas com sucesso no $MYCNF_PATH."

# Registra log
mkdir -p "$(dirname "$LOG_PATH")"
echo "[$TIMESTAMP] Perfil: $PERFIL | RAM: ${MEM_TOTAL_MB}MB | SO: $(($RESERVA_SO / 1024 / 1024))MB | Buffer Pool: $(($BUFFER_POOL_BYTES / 1024 / 1024))MB | max_connections: $MAX_CONNECTIONS" >> "$LOG_PATH"

# Reinicia o serviço MySQL automaticamente
echo "Reiniciando o servico MySQL..."
systemctl restart mysql && echo "MySQL reiniciado com sucesso." || echo "Erro ao reiniciar o MySQL."
