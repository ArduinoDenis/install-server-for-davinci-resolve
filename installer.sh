#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}


handle_error() {
    log_error "Errore durante l'esecuzione del comando precedente"
    log_error "Script terminato con errore alla riga $1"
    exit 1
}

trap 'handle_error $LINENO' ERR
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Non eseguire questo script come root!"
        log_info "Lo script richiederà i permessi sudo quando necessario"
        exit 1
    fi
}


check_internet() {
    log_info "Verifico la connessione internet..."
    if ! ping -c 1 google.com &> /dev/null; then
        log_error "Connessione internet non disponibile"
        exit 1
    fi
    log_success "Connessione internet verificata"
}


update_system() {
    log_info "Aggiornamento lista pacchetti e sistema..."
    if sudo apt update && sudo apt full-upgrade -y; then
        log_success "Sistema aggiornato con successo"
    else
        log_error "Errore durante l'aggiornamento del sistema"
        exit 1
    fi
}


install_postgresql() {
    log_info "Aggiunta repository PostgreSQL..."
    
    local codename=$(lsb_release -cs)
    
    sudo sh -c "echo 'deb http://apt.postgresql.org/pub/repos/apt $codename-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
    if ! wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee /etc/apt/trusted.gpg.d/pgdg.asc &>/dev/null; then
        log_error "Errore nell'aggiunta della chiave GPG PostgreSQL"
        exit 1
    fi
    
    log_info "Installazione PostgreSQL 15..."
    sudo apt update
    if sudo apt install postgresql-15 postgresql-client-15 -y; then
        log_success "PostgreSQL installato con successo"
    else
        log_error "Errore durante l'installazione di PostgreSQL"
        exit 1
    fi
}


configure_postgresql() {
    log_info "Configurazione PostgreSQL..."
    
    sudo cp /etc/postgresql/15/main/postgresql.conf /etc/postgresql/15/main/postgresql.conf.backup
    sudo cp /etc/postgresql/15/main/pg_hba.conf /etc/postgresql/15/main/pg_hba.conf.backup
    
    log_warning "ATTENZIONE: Devi configurare manualmente i seguenti file:"
    log_info "1. /etc/postgresql/15/main/postgresql.conf"
    log_info "2. /etc/postgresql/15/main/pg_hba.conf"
    
    read -p "Premi INVIO per aprire il primo file di configurazione (postgresql.conf)..."
    sudo nano /etc/postgresql/15/main/postgresql.conf
    
    read -p "Premi INVIO per aprire il secondo file di configurazione (pg_hba.conf)..."
    sudo nano /etc/postgresql/15/main/pg_hba.conf
    
    log_info "Riavvio servizio PostgreSQL..."
    sudo systemctl restart postgresql
    sudo systemctl enable postgresql
    
    log_success "PostgreSQL configurato e riavviato"
}


setup_database() {
    log_info "Configurazione database PostgreSQL..."
    log_warning "Ora verrai collegato come utente postgres per configurare il database"
    log_info "Comandi suggeriti da eseguire:"
    log_info "  CREATE USER davinci WITH PASSWORD 'your_password';"
    log_info "  CREATE DATABASE davinci OWNER davinci;"
    log_info "  GRANT ALL PRIVILEGES ON DATABASE davinci TO davinci;"
    log_info "  \\q (per uscire)"
    
    read -p "Premi INVIO per continuare..."
    sudo -i -u postgres psql
}


install_pgadmin() {
    log_info "Aggiunta repository pgAdmin4..."
    
    if ! curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/packages-pgadmin-org.gpg; then
        log_error "Errore nell'aggiunta della chiave GPG pgAdmin4"
        exit 1
    fi
    
    local codename=$(lsb_release -cs)
    sudo sh -c "echo 'deb [signed-by=/usr/share/keyrings/packages-pgadmin-org.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$codename pgadmin4 main' > /etc/apt/sources.list.d/pgadmin4.list"
    
    sudo apt update
    
    log_info "Installazione pgAdmin4-web..."
    if sudo apt install pgadmin4-web -y; then
        log_success "pgAdmin4 installato con successo"
    else
        log_error "Errore durante l'installazione di pgAdmin4"
        exit 1
    fi
}


configure_pgadmin() {
    log_info "Configurazione pgAdmin4-web..."
    log_warning "Ti verrà chiesto di impostare email e password per pgAdmin4"
    
    if sudo /usr/pgadmin4/bin/setup-web.sh; then
        log_success "pgAdmin4 configurato con successo"
        log_info "pgAdmin4 sarà accessibile tramite browser all'indirizzo:"
        log_info "http://localhost/pgadmin4"
    else
        log_error "Errore durante la configurazione di pgAdmin4"
        exit 1
    fi
}


install_davinci_server() {
    log_info "Installazione server DaVinci Resolve..."
    log_warning "Verifica che il link di installazione sia ancora valido"
    
    if ! curl -Is https://wirebear.co.uk/software/studio-server-client/install | head -n 1 | grep -q "200 OK"; then
        log_error "Il link di installazione del server DaVinci non è raggiungibile"
        log_info "Verifica manualmente: https://wirebear.co.uk/software/studio-server-client/install"
        exit 1
    fi
    
    if bash -c "$(wget https://wirebear.co.uk/software/studio-server-client/install -O -)"; then
        log_success "Server DaVinci Resolve installato con successo"
    else
        log_error "Errore durante l'installazione del server DaVinci Resolve"
        exit 1
    fi
}


final_summary() {
    log_success "=== INSTALLAZIONE COMPLETATA ==="
    log_info "Componenti installati:"
    log_info "  ✓ PostgreSQL 15"
    log_info "  ✓ pgAdmin4-web"
    log_info "  ✓ Server DaVinci Resolve"
    
    echo
    log_info "Passi successivi:"
    log_info "1. Accedi a pgAdmin4: http://localhost/pgadmin4"
    log_info "2. Configura la connessione al database PostgreSQL"
    log_info "3. Avvia DaVinci Resolve e configura la connessione al database"
    
    echo
    log_warning "File di backup creati:"
    log_info "  - /etc/postgresql/15/main/postgresql.conf.backup"
    log_info "  - /etc/postgresql/15/main/pg_hba.conf.backup"
}


main() {
    log_info "=== INSTALLAZIONE SERVER DAVINCI RESOLVE ==="
    log_info "Questo script installerà:"
    log_info "  - PostgreSQL 15"
    log_info "  - pgAdmin4-web"
    log_info "  - Server DaVinci Resolve"
    
    echo
    read -p "Vuoi continuare? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installazione annullata dall'utente"
        exit 0
    fi
    
    check_root
    check_internet
    update_system
    install_postgresql
    configure_postgresql
    setup_database
    install_pgadmin
    configure_pgadmin
    install_davinci_server
    final_summary
    
    log_success "Script completato con successo!"
}


main "$@"
