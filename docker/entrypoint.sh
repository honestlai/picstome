#!/bin/sh
set -e

cd /var/www/html

ROLE="${PICSTOME_CONTAINER_ROLE:-web}"
BOOTSTRAP_MARKER="storage/app/.picstome_container_bootstrapped"
APP_KEY_FILE="storage/app/.picstome_app_key"

mkdir -p \
    storage/app/private \
    storage/app/public \
    storage/framework/cache/data \
    storage/framework/sessions \
    storage/framework/views \
    storage/logs \
    bootstrap/cache \
    database

# Persist APP_KEY on the storage volume when not supplied (Portainer-friendly).
if [ -z "${APP_KEY:-}" ] && [ -f "$APP_KEY_FILE" ]; then
    APP_KEY=$(tr -d '\n\r' <"$APP_KEY_FILE")
    export APP_KEY
fi

if [ -z "${APP_KEY:-}" ]; then
    APP_KEY="base64:$(php -r 'echo base64_encode(random_bytes(32));')"
    printf '%s' "$APP_KEY" >"$APP_KEY_FILE"
    export APP_KEY
fi

# SQLite: ensure database file exists (see upstream README: touch database/database.sqlite).
if [ "${DB_CONNECTION:-sqlite}" = "sqlite" ]; then
    DBFILE="${DB_DATABASE:-database/database.sqlite}"
    case "$DBFILE" in
        /*) ;;
        *) DBFILE="/var/www/html/$DBFILE" ;;
    esac
    mkdir -p "$(dirname "$DBFILE")"
    if [ ! -f "$DBFILE" ]; then
        touch "$DBFILE"
    fi
fi

chown -R www-data:www-data storage bootstrap/cache database 2>/dev/null || true
chmod -R ug+rwx storage bootstrap/cache database 2>/dev/null || true

php artisan package:discover --no-interaction 2>/dev/null || true

if [ "$ROLE" = "web" ]; then
    if [ "${PICSTOME_AUTO_MIGRATE:-1}" = "1" ]; then
        php artisan migrate --force --no-interaction
    fi

    if [ "${PICSTOME_SKIP_STORAGE_LINK:-0}" != "1" ]; then
        php artisan storage:link --force --no-interaction 2>/dev/null || true
    fi

    if [ ! -f "$BOOTSTRAP_MARKER" ]; then
        if [ "${PICSTOME_SEED_ON_FIRST_BOOT:-0}" = "1" ]; then
            php artisan db:seed --force --no-interaction
        fi
        : >"$BOOTSTRAP_MARKER"
    fi

    if [ "${PICSTOME_OPTIMIZE:-1}" = "1" ]; then
        php artisan config:cache --no-interaction
        php artisan route:cache --no-interaction
        php artisan view:cache --no-interaction
        chown -R www-data:www-data storage bootstrap/cache || true
    fi
fi

exec "$@"
