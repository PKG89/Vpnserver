#!/bin/bash

set -e  # Выход при ошибках
set -u  # Выход при использовании неинициализированной переменной

# Функция для обработки ошибок
error_exit() {
    echo "❌ Ошибка на строке $1: $2"
    exit 1
}
trap 'error_exit $LINENO "$BASH_COMMAND"' ERR

# Запрос ключевых параметров у пользователя
read -p "Введите пароль для root пользователя MariaDB: " MARIADB_ROOT_PASSWORD
read -p "Введите имя базы данных: " MARIADB_DATABASE
read -p "Введите имя пользователя базы данных: " MARIADB_USER
read -p "Введите пароль для пользователя $MARIADB_USER: " MARIADB_PASSWORD

# Проверка наличия Docker и Docker Compose
echo "🔍 Проверка установки Docker и Docker Compose..."
if ! command -v docker &> /dev/null; then
    echo "⚠️ Docker не найден. Устанавливаю..."
    sudo apt update
    sudo apt install -y docker.io
fi

if ! command -v docker-compose &> /dev/null; then
    echo "⚠️ Docker Compose не найден. Устанавливаю..."
    sudo apt install -y docker-compose
fi

echo "✅ Docker и Docker Compose установлены."

# Добавление пользователя в группу docker
echo "👤 Добавление пользователя $(whoami) в группу Docker..."
sudo usermod -aG docker $(whoami)
newgrp docker

# Создание каталога для MariaDB
INSTALL_DIR=~/mariadb-docker
echo "📂 Создание каталога $INSTALL_DIR"
mkdir -p $INSTALL_DIR && cd $INSTALL_DIR

# Создание docker-compose.yml
echo "📝 Создание docker-compose.yml..."
cat > docker-compose.yml <<EOL
version: '3.8'

services:
  mariadb:
    image: mariadb:latest
    container_name: mariadb_container
    restart: unless-stopped
    ports:
      - "3306:3306"
    environment:
      MARIADB_ROOT_PASSWORD: ${MARIADB_ROOT_PASSWORD}
      MARIADB_DATABASE: ${MARIADB_DATABASE}
      MARIADB_USER: ${MARIADB_USER}
      MARIADB_PASSWORD: ${MARIADB_PASSWORD}
    volumes:
      - mariadb_data:/var/lib/mysql
    networks:
      - mariadb_network

volumes:
  mariadb_data:

networks:
  mariadb_network:
    driver: bridge
EOL

echo "✅ docker-compose.yml создан."

# Запуск контейнера MariaDB
echo "🚀 Запуск MariaDB контейнера..."
docker-compose up -d

# Проверка запуска контейнера
if docker ps | grep -q "mariadb_container"; then
    echo "✅ Контейнер MariaDB успешно запущен."
else
    echo "❌ Ошибка запуска контейнера MariaDB."
    exit 1
fi

# Ожидание запуска контейнера перед проверкой базы данных
echo "⏳ Ожидание запуска MariaDB..."
sleep 10

# Проверка подключения к MariaDB
echo "🔍 Проверка подключения к MariaDB..."
docker exec mariadb_container mysqladmin -u root -p${MARIADB_ROOT_PASSWORD} ping &> /dev/null

if [ $? -eq 0 ]; then
    echo "✅ Успешное подключение к MariaDB!"
else
    echo "❌ Не удалось подключиться к MariaDB. Проверьте параметры."
    exit 1
fi

# Вывод информации о базе данных
echo "📊 Проверка доступных баз данных..."
docker exec mariadb_container mysql -u root -p${MARIADB_ROOT_PASSWORD} -e "SHOW DATABASES;"

echo "🎉 Установка завершена успешно! Данные для подключения:"
echo "  - Хост: $(hostname -I | awk '{print $1}')"
echo "  - Порт: 3306"
echo "  - База данных: ${MARIADB_DATABASE}"
echo "  - Пользователь: ${MARIADB_USER}"
echo "  - Пароль: ${MARIADB_PASSWORD}"

# Автозапуск контейнера при перезагрузке сервера
echo "🔧 Настройка автозапуска контейнера..."
docker update --restart always mariadb_container

# Создание тестовой таблицы (опционально)
read -p "Хотите создать тестовую таблицу в базе? (y/n): " create_table
if [[ $create_table == "y" ]]; then
    echo "🛠️ Создание тестовой таблицы..."
    docker exec mariadb_container mysql -u ${MARIADB_USER} -p${MARIADB_PASSWORD} -D ${MARIADB_DATABASE} -e "CREATE TABLE test (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255));"
    echo "✅ Тестовая таблица создана."
fi

echo "🚀 MariaDB контейнер работает. Используйте команду 'docker ps' для проверки. Ты сможешь подключиться к базе данных с сервера командой: docker exec -it mariadb_container mysql -u root -p"
