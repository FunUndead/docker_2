#!/bin/bash

set -e  # Прерывать выполнение при ошибках

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функции для цветного вывода
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка прав суперпользователя
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warn "Скрипт запущен с правами root"
    else
        print_error "Этот скрипт требует прав суперпользователя для установки в /opt"
        exit 1
    fi
}

# Проверка установки Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker не установлен. Установите Docker перед запуском скрипта."
        exit 1
    fi

    if ! command -v docker compose &> /dev/null; then
        print_error "Docker Compose не установлен. Установите Docker Compose перед запуском скрипта."
        exit 1
    fi

    print_info "Docker и Docker Compose доступны"
}

# Получение информации о репозитории
get_repo_info() {
    # Замените на URL вашего форк-репозитория
    REPO_URL="https://github.com/FunUndead/docker_2.git"
    TARGET_DIR="/opt/my-project"

}

# Скачивание репозитория
clone_repository() {
    local repo_url=$1
    local target_dir=$2

    print_info "Скачивание репозитория из $repo_url в $target_dir"

    if [[ -d "$target_dir" ]]; then
        print_warn "Каталог $target_dir уже существует"
        read -p "Хотите обновить репозиторий? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd "$target_dir"
            git pull origin main
            cd - > /dev/null
        else
            print_info "Используется существующая версия"
        fi
    else
        git clone "$repo_url" "$target_dir"
        if [[ $? -ne 0 ]]; then
            print_error "Ошибка при клонировании репозитория"
            exit 1
        fi
    fi
}

# Проверка структуры проекта
check_project_structure() {
    local project_dir=$1

    print_info "Проверка структуры проекта"

    cd "$project_dir"

    # Проверяем необходимые файлы
    local required_files=("compose.yaml" "Dockerfile.python")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            print_error "Не найден необходимый файл: $file"
            exit 1
        fi
    done

    print_info "Структура проекта проверена успешно"
}

# Сборка и запуск проекта
run_project() {
    local project_dir=$1

    print_info "Переход в каталог проекта: $project_dir"
    cd "$project_dir"

    # Останавливаем предыдущие версии если есть
    print_info "Остановка предыдущих контейнеров"
    docker compose down || true

    # Запуск проекта
    print_info "Запуск проекта"
    docker compose up \-d \-\-build

    # Ожидание запуска сервисов
    print_info "Ожидание запуска сервисов..."
    sleep 10

    # Проверка статуса контейнеров
    print_info "Статус контейнеров:"
    docker compose ps

    # Показ логов приложения
    print_info "Логи приложения (для выхода нажмите Ctrl+C):"
    docker compose logs -f app
}

# Основная функция
main() {
    print_info "Начало установки и запуска проекта"

    # Проверки
    check_root
    check_docker

    # Получение информации о репозитории
    get_repo_info

    # Скачивание репозитория
    clone_repository "$REPO_URL" "$TARGET_DIR"

    # Проверка структуры
    check_project_structure "$TARGET_DIR"

    # Запуск проекта
    run_project "$TARGET_DIR"

    print_info "Проект успешно запущен!"
    print_info "Приложение доступно по адресу: http://localhost:8090"
    print_info "Каталог проекта: $TARGET_DIR"
}

# Обработка сигналов
cleanup() {
    print_warn "Получен сигнал прерывания. Остановка контейнеров..."
    cd "$TARGET_DIR" && docker compose down
    exit 0
}

trap cleanup SIGINT SIGTERM

# Запуск основной функции
main "$@"