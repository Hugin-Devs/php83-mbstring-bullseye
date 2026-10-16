#!/usr/bin/env bash
#
# install.sh — Kit PHP 8.3.35 para Debian 11 Bullseye amd64
#
# Instala/actualiza el set completo de PHP 8.3 (cli, fpm, extensiones)
# a partir de los .deb incluidos en debs/ o descargándolos de los
# mirrors oficiales, con verificación SHA256.
#
# Protecciones:
#   - Dry-run obligatorio: aborta si apt planea ELIMINAR paquetes.
#   - Set coherente: todos los php8.3-* de la misma versión exacta.
#   - Restaura PATH: /usr/bin/php y /usr/sbin/php-fpm.
#   - Arranca y habilita php8.3-fpm (systemd).
#
# Uso:
#   sudo ./install.sh
#   sudo ./install.sh --permitir-remociones   (fuerza si apt quiere borrar algo)
#   curl -fsSL https://raw.githubusercontent.com/Hugin-Devs/php83-mbstring-bullseye/main/install.sh | sudo bash
#
set -euo pipefail

readonly PHP_VER="8.3.35"
readonly PHP_FULL_VER="8.3.35-1+0~20260925.87+debian11~1.gbp19383d"
readonly TARGET_DEBIAN_MAJOR=11
readonly EXPECTED_EXT=(curl gd intl mbstring opcache pgsql readline xml zip)

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
DEBS_DIR="${DEBS_DIR:-$SCRIPT_DIR/debs}"
WORKDIR=""
ALLOW_REMOVALS=0

# nombre_local|URL_oficial|SHA256
PACKAGES=(
  "php8.3-common_${PHP_VER}_amd64.deb|https://packages.sury.org/php/pool/main/p/php8.3/php8.3-common_${PHP_FULL_VER}_amd64.deb|ea4a8eb1892cd310ef2e857e6a65d45e44213cc056aec694839a9a896eeb9781"
  "php8.3-mbstring_${PHP_VER}_amd64.deb|https://packages.sury.org/php/pool/main/p/php8.3/php8.3-mbstring_${PHP_FULL_VER}_amd64.deb|24e6bf53e05d727a6832ed4aadfad21297ccee1e7457362344f027beb094803a"
  "php8.3-opcache_${PHP_VER}_amd64.deb|https://packages.sury.org/php/pool/main/p/php8.3/php8.3-opcache_${PHP_FULL_VER}_amd64.deb|00679da45d835f80395ea3c643807f8f249cb4bb3886f99300cca059053b9d79"
  "php8.3-readline_${PHP_VER}_amd64.deb|https://packages.sury.org/php/pool/main/p/php8.3/php8.3-readline_${PHP_FULL_VER}_amd64.deb|9332433bf5e88f50ead0c1244eb148d0fffe61da799a3967a1606f989690c2d8"
  "php8.3-cli_${PHP_VER}_amd64.deb|https://packages.sury.org/php/pool/main/p/php8.3/php8.3-cli_${PHP_FULL_VER}_amd64.deb|8c8239ad602d1922c44436935df0ea2b753f43dd314fc240e4317b1b13a2f4ff"
  "php8.3-fpm_${PHP_VER}_amd64.deb|https://packages.sury.org/php/pool/main/p/php8.3/php8.3-fpm_${PHP_FULL_VER}_amd64.deb|2a56989258e6722bfbf6a22ffd970e54c3373275833cd3b2b342a670e99a825e"
  "php8.3-curl_${PHP_VER}_amd64.deb|https://packages.sury.org/php/pool/main/p/php8.3/php8.3-curl_${PHP_FULL_VER}_amd64.deb|d8696fbc5a70fd68051249f657de85bdd615ea32271159e94e6e54a7d96bb24a"
  "php8.3-gd_${PHP_VER}_amd64.deb|https://packages.sury.org/php/pool/main/p/php8.3/php8.3-gd_${PHP_FULL_VER}_amd64.deb|8ccf29d266bec2cc7fb3ea6cace3ab0299e8e4bdf01d630794135225a9ef7527"
  "php8.3-intl_${PHP_VER}_amd64.deb|https://packages.sury.org/php/pool/main/p/php8.3/php8.3-intl_${PHP_FULL_VER}_amd64.deb|6a94b14b52ff67328f09a15ddb79460b1540397cbf6a9b2bbf9b7ddf2f58ac11"
  "php8.3-pgsql_${PHP_VER}_amd64.deb|https://packages.sury.org/php/pool/main/p/php8.3/php8.3-pgsql_${PHP_FULL_VER}_amd64.deb|be1142cf19aa284f0b5f5950803842e1d540f8d37df0e115de6a7ad1455085da"
  "php8.3-xml_${PHP_VER}_amd64.deb|https://packages.sury.org/php/pool/main/p/php8.3/php8.3-xml_${PHP_FULL_VER}_amd64.deb|23eb2252ff56a710c9ad84bd65ed51c4c436b082b1efb6dae82987920900fe79"
  "php8.3-zip_${PHP_VER}_amd64.deb|https://packages.sury.org/php/pool/main/p/php8.3/php8.3-zip_${PHP_FULL_VER}_amd64.deb|1d4d552d9e1e1a24febb776b9c5cc6303b72ef3f4e4f288a38b465c4b533f976"
  "php-common_101_all.deb|https://packages.sury.org/php/pool/main/p/php-defaults/php-common_101~+0~20260503.72+debian11~1.gbp7da167_all.deb|7728a962ac1898fba824e9ffe0f1d26981f000ac1facfa8922bc38f69dcccbb7"
  "libonig5_6.9.6-1.1_amd64.deb|https://deb.debian.org/debian/pool/main/libo/libonig/libonig5_6.9.6-1.1_amd64.deb|2e7a415a83bbee0d07e0df2d4e099c8e09c914a9769395d609c18937f26ceed1"
  "libssl1.1_1.1.1w-0+deb11u1_amd64.deb|https://deb.debian.org/debian/pool/main/o/openssl/libssl1.1_1.1.1w-0+deb11u1_amd64.deb|aadf8b4b197335645b230c2839b4517aa444fd2e8f434e5438c48a18857988f7"
  "libffi7_3.3-6_amd64.deb|https://deb.debian.org/debian/pool/main/libf/libffi/libffi7_3.3-6_amd64.deb|30ca89bfddae5fa6e0a2a044f22b6e50cd17c4bc6bc850c579819aeab7101f0f"
  "ucf_3.0043_all.deb|https://deb.debian.org/debian/pool/main/u/ucf/ucf_3.0043_all.deb|ebef6bcd777b5c0cc2699926f2159db08433aed07c50cb321fd828b28c5e8d53"
  "psmisc_23.4-2_amd64.deb|https://deb.debian.org/debian/pool/main/p/psmisc/psmisc_23.4-2_amd64.deb|35fc1f6473dced980a683dfbae9244d332a4cb87b7dd004f4369a707bb57d8dd"
)

if [[ -t 1 ]]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YLW=$'\033[33m'; C_BLU=$'\033[34m'; C_OFF=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YLW=""; C_BLU=""; C_OFF=""
fi

info() { printf '%s==>%s %s\n' "$C_BLU" "$C_OFF" "$*"; }
ok()   { printf '%s[OK]%s %s\n' "$C_GRN" "$C_OFF" "$*"; }
warn() { printf '%s[AVISO]%s %s\n' "$C_YLW" "$C_OFF" "$*" >&2; }
die()  { printf '%s[ERROR]%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Uso: sudo $0 [opciones]

Opciones:
  --permitir-remociones  Permite que apt elimine paquetes (por defecto aborta).
  -h, --help             Muestra esta ayuda.
EOF
  exit 0
}

cleanup() { [[ -n "$WORKDIR" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

require_root() {
  [[ $EUID -eq 0 ]] && return 0
  command -v sudo >/dev/null 2>&1 || die "Se requieren privilegios root (sudo no encontrado)."
  info "Re-lanzando con sudo..."
  exec sudo -- "$0" "$@"
}

check_system() {
  local arch
  arch="$(uname -m)"
  [[ "$arch" == "x86_64" ]] || die "Arquitectura no soportada: $arch (se requiere amd64/x86_64)."
  [[ -r /etc/os-release ]] || die "No se pudo detectar el sistema operativo."
  # shellcheck disable=SC1091
  . /etc/os-release
  local major="${VERSION_ID%%.*}"
  if [[ "${ID:-}" == "debian" ]] && [[ "$major" =~ ^[0-9]+$ ]] && (( major != TARGET_DEBIAN_MAJOR )); then
    warn "Debian ${VERSION_ID} detectado; este kit está compilado para Debian ${TARGET_DEBIAN_MAJOR}."
  fi
  ok "Sistema: ${PRETTY_NAME:-Debian ${VERSION_ID:-?}} ($arch)"
}

report_installed() {
  local cur=""
  cur="$(dpkg-query -W -f='${Version}' php8.3-common 2>/dev/null || true)"
  if [[ -z "$cur" ]]; then
    info "php8.3-common: no instalado (instalación nueva del set ${PHP_VER})."
  elif dpkg --compare-versions "$cur" eq "$PHP_FULL_VER"; then
    info "php8.3-common ya está en ${PHP_VER}; se instalarán solo los paquetes faltantes."
  else
    warn "php8.3-common instalado: ${cur} → se actualizará a ${PHP_VER} junto con todo el set."
    warn "Todos los php8.3-* se actualizan a la vez para mantener la coherencia de versión."
  fi
}

gather_debs() {
  WORKDIR="$(mktemp -d)"
  local -a local_debs=()
  local all_local=1 entry fname url sha

  if [[ -d "$DEBS_DIR" ]]; then
    for entry in "${PACKAGES[@]}"; do
      IFS='|' read -r fname _ sha <<<"$entry"
      if [[ -f "$DEBS_DIR/$fname" ]]; then
        actual="$(sha256sum "$DEBS_DIR/$fname" | awk '{print $1}')"
        [[ "$actual" == "$sha" ]] || die "SHA256 incorrecto en $DEBS_DIR/$fname"
        local_debs+=("$DEBS_DIR/$fname")
      else
        all_local=0
      fi
    done
  else
    all_local=0
  fi

  if (( all_local )); then
    ok "Usando los ${#local_debs[@]} .deb incluidos en $DEBS_DIR (modo offline)."
    printf '%s\n' "${local_debs[@]}" >"$WORKDIR/paths.txt"
    return 0
  fi

  info "Descargando paquetes de los mirrors oficiales..."
  command -v curl >/dev/null 2>&1 || die "Se requiere curl para descargar los paquetes."
  : >"$WORKDIR/paths.txt"
  for entry in "${PACKAGES[@]}"; do
    IFS='|' read -r fname url sha <<<"$entry"
    local dest="$WORKDIR/$fname"
    if [[ -f "$DEBS_DIR/$fname" ]]; then
      cp -- "$DEBS_DIR/$fname" "$dest"
    else
      info "  → $fname"
      curl -fsSL --retry 3 --retry-delay 2 -o "$dest" "$url" \
        || die "No se pudo descargar $fname desde $url"
    fi
    verify_sha256 "$dest" "$sha"
    printf '%s\n' "$dest" >>"$WORKDIR/paths.txt"
  done
  ok "Paquetes descargados y verificados."
}

verify_sha256() {
  local file="$1" expected="$2" actual
  actual="$(sha256sum "$file" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || die "SHA256 incorrecto en $(basename "$file"): esperado $expected, obtenido $actual"
}

select_to_install() {
  local -a out=()
  local path pkg ver cur
  while IFS= read -r path; do
    pkg="$(dpkg-deb -f "$path" Package)"
    ver="$(dpkg-deb -f "$path" Version)"
    cur="$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null || true)"
    if [[ -n "$cur" ]] && dpkg --compare-versions "$cur" ge "$ver"; then
      info "Omitido $pkg (ya instalado: $cur >= $ver)."
    else
      out+=("$path")
    fi
  done <"$WORKDIR/paths.txt"
  printf '%s\n' "${out[@]}" >"$WORKDIR/to_install.txt"
  if (( ${#out[@]} == 0 )); then
    ok "Todos los paquetes del kit ya están instalados."
  else
    info "${#out[@]} paquete(s) a instalar/actualizar."
  fi
}

simulate_or_die() {
  local -a pkgs=()
  mapfile -t pkgs <"$WORKDIR/to_install.txt"
  (( ${#pkgs[@]} == 0 )) && return 0

  info "Simulando instalación (dry-run) para detectar eliminaciones..."
  export LC_ALL=C
  if ! apt-get install -s --no-install-recommends "${pkgs[@]}" >"$WORKDIR/sim.txt" 2>&1; then
    cat "$WORKDIR/sim.txt" >&2
    die "apt no pudo resolver la instalación. Revisa los mensajes anteriores."
  fi

  if grep -qE '^Remv ' "$WORKDIR/sim.txt"; then
    warn "¡ATENCIÓN! apt planea ELIMINAR estos paquetes:"
    grep -E '^Remv ' "$WORKDIR/sim.txt" | awk '{print "  - " $2}' >&2
    if (( ALLOW_REMOVALS )); then
      warn "Continuando porque se pasó --permitir-remociones."
    else
      die "Instalación abortada: se eliminarían paquetes. Ejecuta con --permitir-remociones si realmente quieres eso."
    fi
  else
    ok "Dry-run limpio: la instalación no elimina ningún paquete."
  fi
}

install_debs() {
  local -a pkgs=()
  mapfile -t pkgs <"$WORKDIR/to_install.txt"
  (( ${#pkgs[@]} == 0 )) && return 0

  info "Instalando ${#pkgs[@]} paquete(s)..."
  export DEBIAN_FRONTEND=noninteractive LC_ALL=C
  apt-get install -y --no-install-recommends "${pkgs[@]}" \
    || die "La instalación falló. Revisa los mensajes anteriores."
  ok "Instalación completada."
}

fix_path() {
  local php_bin="" fpm_bin=""
  if command -v php8.3 >/dev/null 2>&1; then
    php_bin="$(command -v php8.3)"
  fi
  if command -v php8.3-fpm >/dev/null 2>&1; then
    fpm_bin="$(command -v php8.3-fpm)"
  elif [[ -x /usr/sbin/php8.3-fpm ]]; then
    fpm_bin="/usr/sbin/php8.3-fpm"
  fi

  if [[ -n "$php_bin" && ! -e /usr/bin/php ]]; then
    ln -s "$(basename "$php_bin")" /usr/bin/php
    ok "Creado /usr/bin/php → $(basename "$php_bin")"
  fi

  if [[ -n "$fpm_bin" && ! -e /usr/sbin/php-fpm ]]; then
    ln -s "$(basename "$fpm_bin")" /usr/sbin/php-fpm
    ok "Creado /usr/sbin/php-fpm → $(basename "$fpm_bin")"
  fi
}

start_service() {
  if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    info "Habilitando e iniciando php8.3-fpm..."
    systemctl enable php8.3-fpm >/dev/null 2>&1 || true
    systemctl restart php8.3-fpm && ok "Servicio php8.3-fpm activo." \
      || warn "No se pudo reiniciar php8.3-fpm automáticamente; revisa: systemctl status php8.3-fpm"
  else
    warn "systemd no está activo; inicia FPM manualmente: php8.3-fpm"
  fi
}

verify_install() {
  local php_bin="" ext missing=()

  if command -v php8.3 >/dev/null 2>&1; then
    php_bin="php8.3"
  elif command -v php >/dev/null 2>&1; then
    php_bin="php"
  else
    die "No se encontró el binario php en el PATH."
  fi

  ok "PHP: $("$php_bin" -v | head -1)"

  local mods
  mods="$("$php_bin" -m 2>/dev/null)"
  for ext in "${EXPECTED_EXT[@]}"; do
    grep -qix "$ext" <<<"$mods" || missing+=("$ext")
  done
  if (( ${#missing[@]} > 0 )); then
    die "Extensiones que faltan: ${missing[*]}"
  fi
  ok "Extensiones activas: ${EXPECTED_EXT[*]}"
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --permitir-remociones) ALLOW_REMOVALS=1 ;;
      -h|--help) usage ;;
      *) die "Opción desconocida: $1 (usa --help)" ;;
    esac
    shift
  done

  require_root "$@"
  export LC_ALL=C
  info "Kit PHP ${PHP_VER} — Debian ${TARGET_DEBIAN_MAJOR} Bullseye amd64"
  check_system
  report_installed
  gather_debs
  select_to_install
  simulate_or_die
  install_debs
  fix_path
  start_service
  verify_install
  ok "Todo listo."
}

main "$@"
