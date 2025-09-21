# Configuração de Monitoramento com Prometheus e Grafana

Este README detalha os passos para configurar o Prometheus e o Grafana para monitoramento de sistemas Linux (via Node Exporter) e Windows (via Windows Exporter). A configuração inclui a coleta de métricas, visualização em dashboards e a integração entre as ferramentas, fornecendo uma base sólida para a observabilidade da sua infraestrutura.

## 1. Prometheus

O Prometheus é um sistema de monitoramento e alerta de código aberto que coleta métricas de alvos configurados em intervalos definidos, avalia regras de expressão, exibe os resultados e pode acionar alertas se certas condições forem observadas. Sua arquitetura pull-based o torna eficiente para coletar dados de diversas fontes.

### 1.1. Coleta de Métricas com Node Exporter (Linux)

O Node Exporter é responsável por expor métricas de hardware e sistema operacional (como uso de CPU, memória, disco, rede, estatísticas de kernel) em sistemas Linux. Ele atua como um agente leve que expõe um endpoint HTTP (`/metrics`) para o Prometheus coletar dados.

1.  **Download do Node Exporter:**
    Acesse a página de downloads do Prometheus e baixe a versão mais recente do `node_exporter` para Linux, compatível com a arquitetura do seu sistema (geralmente `amd64`).
    - [Prometheus Exporter](https://prometheus.io/download/#node_exporter)

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
```
###  1.3. Execução do Prometheus (Docker)
Para executar o Prometheus de forma isolada e facilitar o gerenciamento, é altamente recomendado usar Docker. Para garantir que os dados do Prometheus sejam persistidos mesmo se o container for removido ou recriado, use um volume.
```bash
# Crie um volume Docker para persistir os dados do Prometheus
docker volume create prometheus_data

# Execute o container do Prometheus
docker container run -d \
  -p 9090:9090 \
  -v /caminho/para/seu/prometheus.yml:/etc/prometheus/prometheus.yml \
  -v prometheus_data:/prometheus \
  --name prometheus \
  prom/prometheus:latest \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/prometheus
```
- Observação:
    - Substitua /caminho/para/seu/prometheus.yml pelo caminho completo do arquivo prometheus.yml no seu sistema host.
    - O volume prometheus_data garante que as métricas coletadas sejam persistidas no disco do host, evitando perda de dados em caso de reinício ou recriação do container.
--config.file e --storage.tsdb.path são argumentos passados para o binário do Prometheus dentro do container.
    - O dashboard do Prometheus estará acessível em http://localhost:9090. Você pode verificar o status dos seus alvos em http://localhost:9090/targets.

## 2 Grafana
O Grafana é uma plataforma de código aberto para análise e visualização de dados. Ele permite criar dashboards interativos a partir de diversas fontes de dados (Data Sources), incluindo o Prometheus, facilitando a interpretação de métricas complexas.

### 2.1. Execução do Grafana (Docker)
Assim como o Prometheus, o Grafana deve ser executado com um volume persistente para manter suas configurações, dashboards e dados de usuário.
```bash
# Crie um volume Docker para persistir os dados do Grafana
docker volume create grafana_data

# Execute o container do Grafana
docker container run -d \
  -p 3000:3000 \
  -v grafana_data:/var/lib/grafana \
  --name grafana \
  grafana/grafana:latest
```
- Observação: O volume grafana_data é crucial para preservar seus dashboards e configurações do Grafana.

Após iniciar o container, acesse o Grafana em http://localhost:3000. As credenciais padrão são:

    - Usuário: admin
    - Senha: admin Você será solicitado a alterar a senha no primeiro login.

### 2.2. Configuração do Prometheus como Data Source no Grafana
Para que o Grafana possa buscar e exibir as métricas do Prometheus, você precisa configurá-lo como um Data Source.

1. No Grafana, vá para Configuration (ícone de engrenagem no menu lateral) -> Data Sources.
2. Clique em Add data source.
3. Selecione Prometheus.
4. No campo URL, insira:
- http://host.docker.internal:9090 se você estiver executando o Grafana e o Prometheus em containers Docker separados, mas o Prometheus está acessível via localhost do host (Docker Desktop no Windows/macOS).
- http://172.17.0.1:9090 (ou o IP do seu Docker bridge network) se ambos os containers estiverem na rede padrão bridge do Docker no Linux e o Prometheus estiver no host.
- Recomendado (com Docker Compose): http://prometheus:9090 se você estiver usando Docker Compose e o serviço Prometheus for nomeado prometheus na mesma rede Docker. (Veja a seção 4 para Docker Compose).
- Deixe as outras configurações como padrão, a menos que você tenha requisitos específicos (e.g., autenticação).
- Clique em Save & Test. Você deve ver uma mensagem de sucesso como "Data source is working".

### 2.3. Importação de Dashboard para Node Exporter Full
O Grafana possui uma vasta biblioteca de dashboards pré-construídos. Para visualizar as métricas do Node Exporter de forma abrangente, importe o dashboard "Node Exporter Full".

1. Acesse o link do dashboard raw: 
2. Clique no botão "Raw" para obter o conteúdo JSON puro. Copie todo o conteúdo.
3. o Grafana, vá para Dashboards (ícone de quadro no menu lateral) -> + New Dashboard -> Import.
4. Cole o JSON copiado no campo "Import via panel json".
5. Clique em Load.
6. Na tela seguinte, você pode ajustar o nome e a pasta do dashboard. Certifique-se de selecionar o data source Prometheus que você configurou no campo "Prometheus".
7. Clique em Import. Você agora terá um dashboard detalhado exibindo as métricas do seu sistema Linux.

## 3. Prometheus no Windows
Para monitorar sistemas Windows, utilizamos o `windows_exporter`, que funciona de forma similar ao Node Exporter, expondo métricas específicas do Windows.

### 3.1. Download e Instalação do Windows Exporter
1. Acesse a página de releases do windows_exporter: 
2. Baixe o arquivo windows_exporter-x.x.x-amd64.msi (substitua x.x.x pela versão mais recente e estável).
3. Execute o instalador .msi e siga as instruções. O instalador geralmente configura o windows_exporter como um serviço do Windows. Considerações durante a instalação: Você pode escolher quais "collectors" (coletores de métricas) deseja habilitar ou desabilitar. Por padrão, os mais comuns (CPU, Memory, Network, Disk) são ativados.
4. Após a instalação, o Windows Exporter será executado como um serviço e exporá as métricas na porta 9182 (ex: http://localhost:9182/metrics). Verificação: Para verificar, acesse http://localhost:9182/metrics no navegador do servidor Windows. Firewall: Certifique-se de que a porta 9182 esteja aberta no firewall do servidor Windows para permitir o acesso do Prometheus.

### 3.2. Configuração do Prometheus para Windows Exporter
Adicione um novo job_name ao seu arquivo prometheus.yml para coletar métricas do Windows Exporter.
```yaml
# prometheus.yml (exemplo com Node Exporter e Windows Exporter)
global:
  scrape_interval: 15s
  scrape_timeout: 10s
  evaluation_interval: 15s

rule_files:
  # - "alert.rules"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter_linux'
    static_configs:
      - targets: ['192.168.56.8:9100'] # IP do seu target Linux

  - job_name: 'windows_exporter' # Novo job para o Windows Exporter
    static_configs:
      - targets: ['192.168.56.9:9182'] # Substitua '192.168.56.9' pelo IP real do seu target Windows.
```
Após modificar o `prometheus.yml`, você precisará reiniciar o container do Prometheus para que as alterações sejam aplicadas:
```bash
docker stop prometheus
docker rm prometheus
# Em seguida, execute o comando 'docker container run' da seção 1.3 novamente
# Ou, se estiver usando Docker Compose, use 'docker-compose up -d --force-recreate prometheus'
```
### 3.3. Configuração do Dashboard do Grafana para Windows
Para visualizar as métricas do Windows Exporter no Grafana:

1. Certifique-se de que o Prometheus esteja configurado para coletar métricas do Windows Exporter e que o Prometheus esteja configurado como data source no Grafana.
2. Importe o dashboard "Windows Node Exporter" com o ID 14510 (ou procure por "Windows Exporter" em grafana.com/grafana/dashboards).
    - No Grafana, vá para Dashboards (ícone de quadro) -> + New Dashboard -> Import.
    - No campo "Import via grafana.com dashboard", insira 14510.
    - Clique em Load.
    - Na tela seguinte, selecione o data source Prometheus que você configurou.
    - Clique em Import. Agora você terá um dashboard para monitorar seus sistemas Windows.
