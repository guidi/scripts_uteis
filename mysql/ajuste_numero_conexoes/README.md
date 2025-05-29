# MySQL Config Tuner

Este script automatiza o ajuste das principais configurações de desempenho do MySQL com base na memória RAM disponível e no perfil de uso definido.

Ele atualiza o arquivo `my.cnf`, aplica os ajustes e reinicia o serviço MySQL de forma automática, além de registrar logs com os valores aplicados.

---

## 📌 Parâmetros ajustados automaticamente

- `max_connections`
- `innodb_buffer_pool_size`
- `wait_timeout` (180 segundos)
- `interactive_timeout` (180 segundos)

---

## 📊 Perfis disponíveis

Definidos diretamente no script via a variável `PERFIL`.

| Perfil       | Uso do buffer pool | Uso para conexões |
|--------------|--------------------|-------------------|
| `performance`| 75%                | 25%               |
| `balanceado` | 62.5%              | 37.5%             |
| `escala`     | 50%                | 50%               |

---

## 🧠 Reserva para o sistema operacional

O script reserva **10% da RAM total** para o SO, com um valor **mínimo de 512MB**, garantindo que o MySQL não consuma toda a memória da máquina.

---

## 🗂 Exemplo de log gerado

O log é salvo em: `/var/log/mysql_config_tuning.log`

```txt
[29/05/2025 15:00:12 GMT-3] Perfil: balanceado | RAM: 8192MB | SO: 819MB | Buffer Pool: 4485MB | max_connections: 192
```

---

## ✅ Requisitos

- Linux com Bash
- Permissão para editar `/etc/mysql/my.cnf`
- Serviço `mysql` gerenciado por `systemctl`
- Ferramenta `bc` instalada (`apt install bc`)

---

## 🚀 Como usar

1. Clone este repositório ou copie o script para a máquina onde o MySQL está instalado.
2. Ajuste a variável `PERFIL` no topo do script (`performance`, `balanceado`, `escala`).
3. Execute como `root`:

```bash
sudo bash mysql_config_tuner.sh
```

---

## 📌 Observações

- Um backup do `my.cnf` será criado automaticamente.
- As configurações anteriores de `max_connections`, `innodb_buffer_pool_size`, `wait_timeout` e `interactive_timeout` serão removidas antes da inserção dos novos valores.
- O script pode ser executado novamente após upgrade de RAM para recalcular os valores ideais.

---

## 📜 Fonte da fórmula

O cálculo de `max_connections` é baseado no modelo utilizado pelo Amazon RDS:

> max_connections = DBInstanceClassMemory / 12_582_880

Referência:  
https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Limits.html#RDS_Limits.MaxConnections

---

## 🔒 Segurança

Este script não expõe nenhuma credencial e não realiza acesso ao banco de dados diretamente.

---

## 🛠 Contribuições

Pull requests são bem-vindos! Se tiver sugestões de melhorias ou suporte a novos perfis, fique à vontade para contribuir.

---

## 🧑‍💻 Autor

Vanderson Guidi  
Arquiteto de Sistemas | [LinkedIn](https://www.linkedin.com/in/vandersonguidi/)
