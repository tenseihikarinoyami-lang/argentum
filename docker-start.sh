#!/bin/bash

###############################################################################
# ARGENTUM Trading Bot - Docker Quick Start Script
# Automated deployment and management
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║         ARGENTUM Trading Bot - Docker Management              ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        echo "Install Docker from: https://www.docker.com"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        echo "Install Docker Compose from: https://docs.docker.com/compose/install"
        exit 1
    fi
    
    print_success "Docker and Docker Compose are installed"
}

check_config() {
    if [ ! -f "config.json" ]; then
        print_warning "config.json not found"
        if [ -f "config.example.json" ]; then
            print_info "Creating config.json from example..."
            cp config.example.json config.json
            print_success "config.json created (please edit with your settings)"
        else
            print_error "Neither config.json nor config.example.json found"
            exit 1
        fi
    else
        print_success "config.json found"
    fi
}

build_image() {
    print_info "Building Docker image (this may take a few minutes)..."
    docker-compose build --no-cache
    print_success "Docker image built successfully"
}

start_bot() {
    print_info "Starting ARGENTUM bot..."
    docker-compose up -d
    
    # Wait for bot to be ready
    print_info "Waiting for bot to be ready..."
    sleep 10
    
    # Check health
    if docker-compose exec -T argentum curl -f http://localhost:5000/api/status > /dev/null 2>&1; then
        print_success "Bot started successfully"
        show_urls
    else
        print_warning "Bot is starting up, may take a moment..."
        show_urls
    fi
}

stop_bot() {
    print_info "Stopping ARGENTUM bot..."
    docker-compose down
    print_success "Bot stopped"
}

restart_bot() {
    print_info "Restarting ARGENTUM bot..."
    docker-compose restart
    sleep 5
    print_success "Bot restarted"
}

show_logs() {
    docker-compose logs -f
}

show_status() {
    echo ""
    print_info "Docker Container Status:"
    docker-compose ps
    echo ""
    
    if docker-compose ps | grep -q "Up"; then
        print_success "Bot is running"
        show_urls
    else
        print_error "Bot is not running"
    fi
}

show_urls() {
    echo ""
    print_info "Access Points:"
    echo "  • Web Dashboard:   ${BLUE}http://localhost:5000${NC}"
    echo "  • API Status:      ${BLUE}http://localhost:5000/api/status${NC}"
    echo "  • Signals:         ${BLUE}http://localhost:5000/api/signals${NC}"
    echo "  • Statistics:      ${BLUE}http://localhost:5000/api/statistics${NC}"
    echo ""
}

run_tests() {
    print_info "Running mode tests..."
    docker-compose exec -T argentum python test_modes_execution.py
}

clean_up() {
    print_warning "This will remove the container and volumes (data will be lost)"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose down -v
        print_success "Cleaned up"
    else
        print_info "Cancelled"
    fi
}

show_help() {
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  build       Build Docker image"
    echo "  start       Start the bot"
    echo "  stop        Stop the bot"
    echo "  restart     Restart the bot"
    echo "  status      Show bot status"
    echo "  logs        Show real-time logs"
    echo "  test        Run mode tests"
    echo "  clean       Remove containers and volumes"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start       # Start bot in background"
    echo "  $0 logs        # Watch logs in real-time"
    echo "  $0 status      # Check if bot is running"
    echo "  $0 test        # Verify all modes work"
    echo ""
}

main() {
    print_header
    
    # Check prerequisites
    check_docker
    check_config
    
    # Handle command
    case "${1:-start}" in
        build)
            build_image
            ;;
        start)
            build_image
            start_bot
            ;;
        stop)
            stop_bot
            ;;
        restart)
            restart_bot
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        test)
            run_tests
            ;;
        clean)
            clean_up
            ;;
        help)
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
    
    echo ""
}

# Run main
main "$@"
