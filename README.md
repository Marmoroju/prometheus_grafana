# Configuração de Monitoramento com Prometheus e Grafana

Este README detalha os passos para configurar o Prometheus e o Grafana para monitoramento de sistemas Linux (via Node Exporter) e Windows (via Windows Exporter). A configuração inclui a coleta de métricas, visualização em dashboards e a integração entre as ferramentas, fornecendo uma base sólida para a observabilidade da sua infraestrutura.

## 1. Prometheus

O Prometheus é um sistema de monitoramento e alerta de código aberto que coleta métricas de alvos configurados em intervalos definidos, avalia regras de expressão, exibe os resultados e pode acionar alertas se certas condições forem observadas. Sua arquitetura pull-based o torna eficiente para coletar dados de diversas fontes.

### 1.1. Coleta de Métricas com Node Exporter (Linux)

O Node Exporter é responsável por expor métricas de hardware e sistema operacional (como uso de CPU, memória, disco, rede, estatísticas de kernel) em sistemas Linux. Ele atua como um agente leve que expõe um endpoint HTTP (`/metrics`) para o Prometheus coletar dados.

1.  **Download do Node Exporter:**
    Acesse a página de downloads do Prometheus e baixe a versão mais recente do `node_exporter` para Linux, compatível com a arquitetura do seu sistema (geralmente `amd64`).
    [https://prometheus.io/download/#node_exporter](https://prometheus.io/download/#node_exporter)

2.  **Instalação e Execução:**
    No servidor Linux que você deseja monitorar (o "target"):

    ```bash
    # Baixar o arquivo (substitua a versão conforme necessário, ex: v1.7.0)
    wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz

    # Descompactar o arquivo
    tar -xvf node_exporter-1.7.0.linux-amd64.tar.gz

    # Mover o diretório descompactado para /opt (ou outro local de sua preferência)
    sudo mv node_exporter-1.7.0.linux-amd64 /opt/node_exporter

    # Criar um usuário de sistema para o Node Exporter (boa prática de segurança)
    sudo useradd -rs /bin/false node_exporter

    # Atribuir propriedade ao usuário node_exporter
    sudo chown -R node_exporter:node_exporter /opt/node_exporter

    # Configurar como um serviço systemd para gerenciamento robusto (recomendado para produção)
    sudo nano /etc/systemd/system/node_exporter.service
    ```
    Adicione o seguinte conteúdo ao arquivo `node_exporter.service`:
    ```ini
    [Unit]
    Description=Node Exporter
    Wants=network-online.target
    After=network-online.target

    [Service]
    User=node_exporter
    Group=node_exporter
    Type=simple
    ExecStart=/opt/node_exporter/node_exporter

    [Install]
    WantedBy=multi-user.target
    ```
    Salve e feche o arquivo. Em seguida, habilite e inicie o serviço:
    ```bash
    sudo systemctl daemon-reload
    sudo systemctl start node_exporter
    sudo systemctl enable node_exporter
    ```
    **Verificação:**
    Para verificar se o Node Exporter está em execução e expondo métricas, acesse `http://<IP_DO_SEU_SERVIDOR_LINUX>:9100/metrics` em um navegador ou use `curl`. Você deverá ver uma grande quantidade de texto com métricas.
    **Firewall:** Certifique-se de que a porta `9100` esteja aberta no firewall do servidor Linux para permitir o acesso do Prometheus.

### 1.2. Configuração do Prometheus (`prometheus.yml`)

O arquivo `prometheus.yml` é o coração da configuração do Prometheus, definindo como ele irá descobrir, coletar e processar métricas dos seus alvos. Este arquivo será montado dentro do container do Prometheus.

```yaml
# prometheus.yml
global:
  scrape_interval: 15s # Intervalo padrão para coletar métricas de todos os jobs
  scrape_timeout: 10s  # Tempo limite para uma coleta de métricas (se excedido, a coleta falha)
  evaluation_interval: 15s # Intervalo para avaliar regras de alerta e gravação

# Regras para alertas (exemplo, pode ser expandido em arquivos separados)
rule_files:
  # - "alert.rules"

scrape_configs:
  # Job para monitorar o próprio Prometheus (útil para verificar o status do monitoramento)
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090'] # O próprio Prometheus expõe métricas em sua porta padrão

  - job_name: 'node_exporter_linux' # Nome do job para o Node Exporter
    # Configurações estáticas são usadas quando os alvos são fixos e conhecidos
    static_configs:
      - targets: ['192.168.56.8:9100'] # Endereço IP e porta do servidor Linux com Node Exporter
                                     # Substitua '192.168.56.8' pelo IP real do seu target Linux.
                                     # Para múltiplos targets, adicione mais entradas:
                                     # - targets: ['192.168.56.9:9100', '192.168.56.10:9100']****
