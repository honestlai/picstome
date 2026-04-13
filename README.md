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

This fork ships a production-oriented [`Dockerfile`](Dockerfile), [`docker-compose.yml`](docker-compose.yml) as a **one-stack** deploy for **Portainer**, and [`docker-compose.build.yml`](docker-compose.build.yml) for local image builds using Flux credentials in `docker/secrets/composer_auth.json` (see [`docker/secrets/composer_auth.json.example`](docker/secrets/composer_auth.json.example)).

**Portainer:** create the external network `docker network create Network-Bridge`, paste the compose file as a stack, then paste the contents of [`docker/sample.env`](docker/sample.env) into the stack **Environment** (advanced) and edit values (especially `APP_URL`, MySQL passwords, and Stripe/AWS as needed). You do not need a separate `.env` file on disk.

The stack includes **PicstomeApp** (nginx + PHP-FPM), **PicstomeQueue**, **PicstomeScheduler**, and **PicstomeDB** (MySQL 8). Named volumes: **`db`** (MySQL data), **`storage`** (uploads, logs, generated `APP_KEY`), **`cache`** (bootstrap cache). In `docker-compose.yml`, the shared `x-laravel-env` block sits under the header because YAML anchors must be defined before `<<: *laravel-env` merges under `services:`. Migrations stay in the image—do not mount over `/var/www/html/database`. Default image: **`ghcr.io/honestlai/picstome:latest`** (`PICSTOME_IMAGE`).

On **first boot**, the entrypoint follows the same provisioning ideas as the [upstream Picstome README](https://github.com/picstome/picstome?tab=readme-ov-file): `php artisan migrate --force`, `php artisan storage:link`, and (if `APP_KEY` is empty) persist a key under `storage/app/.picstome_app_key`. For SQLite instead of MySQL, change `DB_*` in the stack env and add your own DB volume or service—`docker/entrypoint.sh` still creates a SQLite file when `DB_CONNECTION=sqlite`. Optional one-time seed: `PICSTOME_SEED_ON_FIRST_BOOT=1` (this stack never runs `migrate:fresh`). Set `PICSTOME_AUTO_MIGRATE=0` only if you run migrations yourself.

GitHub Actions: add repository secrets **`FLUX_USERNAME`** and **`FLUX_LICENSE_KEY`** so **tests**, **linter**, and **Docker publish** run for real; without them, those workflows **skip** with a green notice (no failure spam). Optional **`DEPLOY_WEBHOOK`** enables the deploy workflow’s curl step.

The workflow [`.github/workflows/docker-publish.yml`](.github/workflows/docker-publish.yml) runs **on GitHub when you push** (not inside your container), builds the image, and pushes to **GHCR** at `ghcr.io/<owner>/<repo>`. Set the package **private** if you want; use a PAT to `docker pull` on your server.
