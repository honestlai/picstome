# syntax=docker/dockerfile:1

FROM composer:2 AS vendor

WORKDIR /app

COPY composer.json composer.lock ./

RUN --mount=type=secret,id=composer_auth \
    sh -c 'export COMPOSER_AUTH="$(cat /run/secrets/composer_auth)" \
    && composer install \
        --no-dev \
        --no-interaction \
        --no-progress \
        --prefer-dist \
        --no-scripts \
        --ignore-platform-reqs'

FROM node:22-bookworm AS frontend

WORKDIR /app

COPY --from=vendor /app/vendor ./vendor

COPY package.json package-lock.json ./

RUN npm ci

COPY resources ./resources
COPY public ./public
COPY lang ./lang
COPY vite.config.js tailwind.config.js postcss.config.js jsconfig.json ./
COPY routes ./routes
COPY app ./app
COPY bootstrap ./bootstrap
COPY config ./config
COPY database ./database
COPY composer.json composer.lock artisan ./

RUN mkdir -p storage/framework/views storage/logs \
    && npm run build

FROM php:8.3-fpm-bookworm

WORKDIR /var/www/html

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        zip \
        unzip \
        nginx \
        supervisor \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libzip-dev \
        libicu-dev \
        libonig-dev \
        libxml2-dev \
        exiftool \
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j"$(nproc)" \
        gd \
        pdo_mysql \
        pdo_sqlite \
        mysqli \
        mbstring \
        exif \
        intl \
        bcmath \
        opcache \
        zip \
        pcntl \
    && docker-php-ext-enable opcache

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

COPY docker/php/conf.d/opcache.ini /usr/local/etc/php/conf.d/opcache.ini
COPY docker/php/php-fpm.d/zz-docker.conf /usr/local/etc/php-fpm.d/zz-docker.conf
COPY docker/nginx/default.conf /etc/nginx/sites-available/default
RUN ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default \
    && rm -f /etc/nginx/sites-enabled/default.bak 2>/dev/null || true

COPY docker/supervisor/picstome.conf /etc/supervisor/conf.d/picstome.conf

COPY --from=vendor /app/vendor ./vendor

COPY . .

RUN composer dump-autoload --optimize --classmap-authoritative --no-interaction \
    && mkdir -p storage/framework/sessions storage/framework/views storage/framework/cache/data storage/logs storage/app/private storage/app/public bootstrap/cache database \
    && chown -R www-data:www-data storage bootstrap/cache database

COPY --from=frontend /app/public/build ./public/build

COPY docker/entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
