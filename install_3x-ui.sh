#!/bin/bash

# Проверка привилегий
if [ "$(id -u)" -ne 0 ]; then
    echo "Пожалуйста, запустите этот скрипт с правами root."
    exit 1
fi

# Установка необходимых пакетов
echo "Устанавливаем зависимости..."
DEPENDENCIES=(wget curl gnupg openssl socat)
for package in "${DEPENDENCIES[@]}"; do
    if ! dpkg -l | grep -qw "$package"; then
        echo "Устанавливаем $package..."
        apt install -y "$package"
    fi
done

# Проверка успешной установки пакетов
for package in "${DEPENDENCIES[@]}"; do
    if ! dpkg -l | grep -qw "$package"; then
        echo "Ошибка установки пакета: $package. Проверьте соединение с интернетом и повторите попытку."
        exit 1
    fi
done
echo "Все зависимости установлены успешно!"

# Установка 3X-UI
echo "Устанавливаем 3X-UI..."
wget -qO- https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh | bash

# Проверка успешной установки 3X-UI
if ! systemctl is-active --quiet x-ui; then
    echo "Ошибка установки 3X-UI. Проверьте логи."
    journalctl -u x-ui -n 50
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
if [ $? -ne 0 ]; then
    echo "Ошибка создания SSL-сертификата. Проверьте openssl."
    exit 1
fi
echo "SSL-сертификат создан успешно!"

# Установка сертификатов в 3X-UI
echo "Настраиваем 3X-UI для работы с SSL..."
CONFIG_FILE="/etc/3x-ui/config.yaml"
if [ -f "$CONFIG_FILE" ]; then
    sed -i 's|sslcertfile:.*|sslcertfile: /etc/3x-ui/ssl/3x-ui.crt|' "$CONFIG_FILE"
    sed -i 's|sslkeyfile:.*|sslkeyfile: /etc/3x-ui/ssl/3x-ui.key|' "$CONFIG_FILE"
else
    echo "Файл конфигурации 3X-UI не найден: $CONFIG_FILE"
    exit 1
fi

# Перезапуск 3X-UI
echo "Перезапускаем 3X-UI для применения изменений..."
systemctl restart x-ui

# Проверка статуса 3X-UI
if systemctl is-active --quiet x-ui; then
    echo "3X-UI успешно настроен и запущен!"
    echo "URL: https://${DOMAIN}:54321"
else
    echo "Ошибка запуска 3X-UI. Проверьте настройки."
    journalctl -u x-ui -n 50
    exit 1
fi

# Вывод статуса и завершение
echo "============================================================"
echo "Установка завершена. Используйте указанный URL для доступа к панели."
echo "============================================================"

# Уведомление об окончании
echo "Спасибо за использование скрипта! Вы великолепны!"
