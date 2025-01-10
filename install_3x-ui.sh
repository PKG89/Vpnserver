#!/bin/bash

# Проверка привилегий
if [ "$(id -u)" -ne 0 ]; then
    echo "Пожалуйста, запустите этот скрипт с правами root."
    exit 1
fi

# Установка необходимых пакетов
echo "Устанавливаем зависимости..."
apt update && apt upgrade -y
apt install -y wget curl gnupg openssl socat

# Установка 3X-UI
echo "Устанавливаем 3X-UI..."
wget -qO- https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh | bash

# Проверка успешной установки 3X-UI
if ! systemctl is-active --quiet 3x-ui; then
    echo "Ошибка установки 3X-UI. Проверьте логи."
    exit 1
fi
echo "3X-UI установлен успешно!"

# Запрос имени домена
read -rp "Введите имя домена или IP (например, example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo "Домен не может быть пустым. Повторите запуск скрипта и укажите домен."
    exit 1
fi

# Настройка самоподписного SSL-сертификата
echo "Создаём самоподписной SSL-сертификат для домена ${DOMAIN} сроком на 10 лет..."

CERT_DIR="/etc/3x-ui/ssl"
mkdir -p "${CERT_DIR}"

openssl req -x509 -newkey rsa:2048 -keyout "${CERT_DIR}/3x-ui.key" -out "${CERT_DIR}/3x-ui.crt" -days 3650 -nodes -subj "/CN=${DOMAIN}"

# Установка сертификатов в 3X-UI
echo "Настраиваем 3X-UI для работы с SSL..."
sed -i 's|sslcertfile:.*|sslcertfile: /etc/3x-ui/ssl/3x-ui.crt|' /etc/3x-ui/config.yaml
sed -i 's|sslkeyfile:.*|sslkeyfile: /etc/3x-ui/ssl/3x-ui.key|' /etc/3x-ui/config.yaml

# Перезапуск 3X-UI
echo "Перезапускаем 3X-UI для применения изменений..."
systemctl restart 3x-ui

# Проверка статуса 3X-UI
if systemctl is-active --quiet 3x-ui; then
    echo "3X-UI успешно настроен и запущен!"
    echo "URL: https://${DOMAIN}:54321"
else
    echo "Ошибка запуска 3X-UI. Проверьте настройки."
    exit 1
fi

echo "Установка завершена. Используйте указанный URL для доступа к панели."
