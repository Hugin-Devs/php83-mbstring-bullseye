# php83-mbstring-bullseye

Instalador del módulo **mbstring de PHP 8.3** para **Debian 11 Bullseye amd64**, con todas sus dependencias obligatorias empaquetadas.

Los `.deb` provienen de los repositorios oficiales:

| Paquete | Origen |
|---|---|
| `php8.3-mbstring` 8.3.35 | [packages.sury.org](https://packages.sury.org/php/) |
| `php8.3-common` 8.3.35 | packages.sury.org |
| `php-common` 2:101 | packages.sury.org |
| `libonig5` 6.9.6-1.1 | deb.debian.org (bullseye) |
| `libssl1.1` 1.1.1w-0+deb11u1 | deb.debian.org (bullseye) |
| `libffi7` 3.3-6 | deb.debian.org (bullseye) |
| `ucf` 3.0043 | deb.debian.org (bullseye) |
| `psmisc` 23.4-2 | deb.debian.org (bullseye) |

Todos los archivos están verificados con SHA256 contra los índices oficiales (`SHA256SUMS`).

## Instalación rápida

En la máquina destino (Debian 11 amd64):

```bash
git clone https://github.com/Hugin-Devs/php83-mbstring-bullseye.git
cd php83-mbstring-bullseye
sudo ./install.sh
```

O en una sola línea (descarga los `.deb` de los mirrors oficiales):

```bash
curl -fsSL https://raw.githubusercontent.com/Hugin-Devs/php83-mbstring-bullseye/main/install.sh | sudo bash
```

## Qué hace el script

1. Verifica que el sistema sea Debian amd64 (advertencia si no es Debian 11).
2. Usa los `.deb` incluidos en `debs/` si están presentes (modo offline), o los descarga de `packages.sury.org` y `deb.debian.org`.
3. Comprueba el SHA256 de cada paquete antes de instalarlo.
4. Omite los paquetes ya instalados en versión igual o superior (evita downgrades).
5. Instala con `apt-get install --no-install-recommends` para resolver el orden de dependencias.
6. Verifica al final que `mbstring` aparezca en `php -m`.

## Verificación manual

```bash
php8.3 -m | grep mbstring
# o
php -m | grep mbstring
```

Salida esperada: `mbstring`.

## Instalación manual (sin el script)

```bash
cd debs/
sudo apt install ./*.deb
```

## Requisitos

- Debian 11 Bullseye (también puede funcionar en otras versiones si las librerías del sistema son compatibles).
- Arquitectura amd64 (x86_64).
- Privilegios root (o sudo).
- `curl` solo si usas el modo descarga (sin `debs/` local).

## Notas

- No añade el repositorio sury a `sources.list`: instala los `.deb` directamente, así que no afecta las actualizaciones del sistema.
- `libssl1.1` y `libffi7` son librerías del sistema de Debian 11; si ya están en versión igual o superior, el script las omite.
- Para otra versión de PHP o de Debian, consulta los índices de <https://packages.sury.org/php/>.

## Licencia

MIT
