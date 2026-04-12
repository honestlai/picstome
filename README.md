## Installation

This project is a standard Laravel application; it is based on Laravel 12 and uses Livewire, Tailwind CSS, and Flux Pro (commercial) for the frontend. If you are familiar with Laravel, you should feel comfortable working on this project. Note: A valid Flux Pro license is required.

For local development, you can use the following requirements:

- PHP 8.3 with SQLite, GD, and other common extensions.
- Node.js 16 or later.
- A valid [Flux Pro](https://fluxui.dev/pricing) license

> **Note for production:**
> If you expect users to download large galleries or files, you should increase the `request_terminate_timeout` setting in your PHP-FPM pool configuration (usually in `/etc/php/8.3/fpm/pool.d/www.conf`).
> For example:
>
> ```
> request_terminate_timeout = 1200
> ```
>
> This prevents PHP-FPM from killing long-running download requests. Make sure to reload PHP-FPM after changing this setting.

If you meet these requirements, you can start by cloning the repository and installing the dependencies.

Using [Composer](https://getcomposer.org) and [NPM](https://www.npmjs.com):

```bash
composer install
composer require livewire/flux-pro

npm install
```

After that, set up your `.env` file:

```bash
cp .env.example .env

php artisan key:generate
```

Set up your database, run the migrations and the seeder:

```bash
touch database/database.sqlite

php artisan migrate:fresh --seed
```

Link the storage to the public folder.

```bash
php artisan storage:link
```

In a **separate terminal**, build the assets in watch mode and start the development server:

```bash
composer run dev
```

## Docker

This fork ships a production-oriented [`Dockerfile`](Dockerfile), [`docker-compose.yml`](docker-compose.yml) for **Portainer** (no `.env` file: variables are defined in the stack with defaults), and [`docker-compose.build.yml`](docker-compose.build.yml) for local image builds using Flux credentials in `docker/secrets/composer_auth.json` (see [`docker/secrets/composer_auth.json.example`](docker/secrets/composer_auth.json.example)).

The compose file expects an external Docker network named **`Network-Bridge`** (`docker network create Network-Bridge`). It runs **app** (nginx + PHP-FPM), **queue**, and **scheduler** against named volumes `storage`, `bootstrap_cache`, and `database`. The default image is **`ghcr.io/honestlai/picstome:latest`** (override with `PICSTOME_IMAGE`).

On **first boot**, the entrypoint follows the same provisioning ideas as the [upstream Picstome README](https://github.com/picstome/picstome?tab=readme-ov-file): ensure SQLite exists when using `DB_CONNECTION=sqlite`, run `php artisan migrate --force`, `php artisan storage:link`, and persist `APP_KEY` under `storage/app/.picstome_app_key` when `APP_KEY` is not set in the environment. Optional one-time seeding: set `PICSTOME_SEED_ON_FIRST_BOOT=1` in Portainer (the upstream README’s `migrate:fresh --seed` is for local development only; this stack never runs `migrate:fresh`). Set `PICSTOME_AUTO_MIGRATE=0` only if you run migrations yourself.

The workflow [`.github/workflows/docker-publish.yml`](.github/workflows/docker-publish.yml) runs **on GitHub when you push code** (it does not run inside your deployed container). It builds the image and uploads it to **GHCR** at `ghcr.io/<owner>/<repo>` so servers can `docker pull` that image. Use the workflow comments to keep the package **private** and to authenticate `docker pull` on your server.
