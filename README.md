# php83-mbstring-bullseye

Kit de **PHP 8.3.35** para **Debian 11 Bullseye amd64**: instalación o restauración del set completo (cli, fpm y extensiones) con verificación SHA256 y protecciones contra eliminación de paquetes.

## Paquetes incluidos (todos en 8.3.35-1+0~20260925.87+debian11~1)

| Paquete | Origen |
|---|---|
| php8.3-common, php8.3-cli, php8.3-fpm | [packages.sury.org](https://packages.sury.org/php/) |
| php8.3-opcache, php8.3-readline, php8.3-curl | packages.sury.org |
| php8.3-gd, php8.3-intl, php8.3-pgsql | packages.sury.org |
| php8.3-xml, php8.3-zip, php8.3-mbstring | packages.sury.org |
| php-common | packages.sury.org |
| libonig5, libssl1.1, libffi7, ucf, psmisc | deb.debian.org (bullseye) |

SHA256 de cada archivo en `SHA256SUMS`.

## Protecciones del instalador

- **Dry-run obligatorio**: simula con `apt-get install -s` y **aborta** si el plan incluye eliminar paquetes (solo se elimina con `--permitir-remociones`).
- **Set coherente**: todos los php8.3-* de la misma versión exacta; una instalación/actualización conjunta nunca deja paquetes incompatibles.
- **Restaura el PATH**: crea `/usr/bin/php` y `/usr/sbin/php-fpm` si no existen.
- **Servicio**: `systemctl enable --now php8.3-fpm`.
- **Verificación final**: comprueba `php -v` y las extensiones curl, gd, intl, mbstring, opcache, pgsql, readline, xml, zip.

## Instalación con internet

```bash
git clone https://github.com/Hugin-Devs/php83-mbstring-bullseye.git
cd php83-mbstring-bullseye
sudo ./install.sh
```

## Restauración offline (red local, sin internet)

Útil si la máquina dañada no tiene salida a internet. Se sirve el kit desde otra máquina de la red (por ejemplo, la que tiene este repo):

**1. En la máquina que tiene el kit** (sirve la carpeta; una de estas opciones):

```bash
cd php83-mbstring-bullseye
python3 -m http.server 8000
# o con FTP:
# pip install pyftpdlib && python3 -m pyftpdlib -p 21
```

**2. En la máquina dañada** (descarga, extrae y ejecuta):

```bash
curl -O http://<ip-de-la-maquina-que-sirve>:8000/php83-restore-8.3.35.tar.gz
tar xzf php83-restore-8.3.35.tar.gz
cd php83-restore-8.3.35
sudo ./install.sh
```

(Con FTP: `curl -O ftp://<ip>/php83-restore-8.3.35.tar.gz` en lugar de la URL HTTP.)

## Verificación manual

```bash
php -v
php -m | grep -E 'curl|gd|intl|mbstring|opcache|pgsql|readline|xml|zip'
ls -la /usr/bin/php /usr/sbin/php-fpm
systemctl status php8.3-fpm
```

## Opciones del script

```bash
sudo ./install.sh --permitir-remociones   # permite que apt elimine paquetes
sudo ./install.sh --help                  # ayuda
```

## Notas

- No añade el repositorio sury a `sources.list`: instala `.deb` sueltos, sin tocar las actualizaciones del sistema.
- Si `php8.3-common` ya está instalado en otra versión, el script avisa y actualiza **todo el set junto** a 8.3.35 (nunca deja un common nuevo con extensiones viejas).
- Las librerías del sistema (`libicu67`, `libpq5`, `libzip4`, `libgd3`, `libcurl4`, etc.) no se tocan.

## Licencia

MIT
