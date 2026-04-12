#!/bin/sh
set -e

cd /var/www/html

mkdir -p \
    storage/app/private \
    storage/app/public \
    storage/framework/cache/data \
    storage/framework/sessions \
    storage/framework/views \
    storage/logs \
    bootstrap/cache \
    database

if [ ! -f database/database.sqlite ] && [ "${DB_CONNECTION:-}" = "sqlite" ]; then
    touch database/database.sqlite || true
fi

chown -R www-data:www-data storage bootstrap/cache database 2>/dev/null || true
chmod -R ug+rwx storage bootstrap/cache database 2>/dev/null || true

php artisan package:discover --no-interaction 2>/dev/null || true

if [ "${PICSTOME_SKIP_STORAGE_LINK:-0}" != "1" ]; then
    php artisan storage:link --force --no-interaction 2>/dev/null || true
fi

if [ "${PICSTOME_OPTIMIZE:-1}" = "1" ]; then
    php artisan config:cache --no-interaction
    php artisan route:cache --no-interaction
    php artisan view:cache --no-interaction
    chown -R www-data:www-data storage bootstrap/cache || true
fi

exec "$@"
