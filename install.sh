#!/usr/bin/env bash
#
# install.sh — PHP 8.3 mbstring para Debian 11 Bullseye amd64
#
# Instala php8.3-mbstring con todas sus dependencias obligatorias.
# Usa los .deb incluidos en debs/ (offline) o los descarga de los
# mirrors oficiales (packages.sury.org y deb.debian.org).
#
# Uso:
#   sudo ./install.sh
#   curl -fsSL https://raw.githubusercontent.com/Hugin-Devs/php83-mbstring-bullseye/main/install.sh | sudo bash
#
set -euo pipefail

readonly PHP_VER="8.3.35"
readonly TARGET_DEBIAN_MAJOR=11

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
DEBS_DIR="${DEBS_DIR:-$SCRIPT_DIR/debs}"
WORKDIR=""

# paquete_local|URL_oficial|SHA256
PACKAGES=(
  "php8.3-mbstring_${PHP_VER}_amd64.deb|https://packages.sury.org/php/pool/main/p/php8.3/php8.3-mbstring_${PHP_VER}-1+0~20260925.87+debian11~1.gbp19383d_amd64.deb|24e6bf53e05d727a6832ed4aadfad21297ccee1e7457362344f027beb094803a"
  "php8.3-common_${PHP_VER}_amd64.deb|https://packages.sury.org/php/pool/main/p/php8.3/php8.3-common_${PHP_VER}-1+0~20260925.87+debian11~1.gbp19383d_amd64.deb|ea4a8eb1892cd310ef2e857e6a65d45e44213cc056aec694839a9a896eeb9781"
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

cleanup() { [[ -n "$WORKDIR" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

require_root() {
  [[ $EUID -eq 0 ]] && return 0
  command -v sudo >/dev/null 2>&1 || die "Se requieren privilegios root (sudo no encontrado). Ejecuta como root."
  info "Re-lanzando con sudo..."
  exec sudo -- "$0" "$@"
}

check_system() {
  local arch
  arch="$(uname -m)"
  [[ "$arch" == "x86_64" ]] || die "Arquitectura no soportada: $arch (se requiere amd64/x86_64)."

  [[ -r /etc/os-release ]] || die "No se pudo detectar el sistema operativo (/etc/os-release ausente)."
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "debian" ]] || warn "Sistema detectado: ${ID:-desconocido} (este paquete está pensado para Debian)."
  local major="${VERSION_ID%%.*}"
  if [[ "$major" =~ ^[0-9]+$ ]] && (( major != TARGET_DEBIAN_MAJOR )); then
    warn "Debian ${VERSION_ID} detectado; los paquetes están compilados para Debian ${TARGET_DEBIAN_MAJOR}."
    warn "Continuando de todos modos por si las versiones de librerías son compatibles."
  fi
  ok "Sistema: ${PRETTY_NAME:-Debian ${VERSION_ID:-?}} ($arch)"
}

verify_sha256() {
  local file="$1" expected="$2" actual
  actual="$(sha256sum "$file" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || die "SHA256 incorrecto en $(basename "$file"): esperado $expected, obtenido $actual"
}

gather_debs() {
  WORKDIR="$(mktemp -d)"
  local -a local_debs=()
  local all_local=1

  if [[ -d "$DEBS_DIR" ]]; then
    for entry in "${PACKAGES[@]}"; do
      IFS='|' read -r fname _ sha <<<"$entry"
      if [[ -f "$DEBS_DIR/$fname" ]]; then
        verify_sha256 "$DEBS_DIR/$fname" "$sha"
        local_debs+=("$DEBS_DIR/$fname")
      else
        all_local=0
      fi
    done
  else
    all_local=0
  fi

  if (( all_local )); then
    ok "Usando los .deb incluidos en $DEBS_DIR (modo offline)."
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

install_debs() {
  local -a to_install=()
  local path pkg ver cur

  while IFS= read -r path; do
    pkg="$(dpkg-deb -f "$path" Package)"
    ver="$(dpkg-deb -f "$path" Version)"
    cur="$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null || true)"
    if [[ -n "$cur" ]] && dpkg --compare-versions "$cur" ge "$ver"; then
      info "Omitido $pkg (ya instalado: $cur >= $ver)."
    else
      to_install+=("$path")
    fi
  done <"$WORKDIR/paths.txt"

  if (( ${#to_install[@]} == 0 )); then
    ok "Todos los paquetes ya están instalados."
    return 0
  fi

  info "Instalando ${#to_install[@]} paquete(s)..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get install -y --no-install-recommends "${to_install[@]}" \
    || die "La instalación falló. Revisa los mensajes anteriores."
  ok "Instalación completada."
}

verify_install() {
  local php_bin=""
  for cand in php8.3 php; do
    if command -v "$cand" >/dev/null 2>&1; then
      php_bin="$cand"
      break
    fi
  done
  [[ -n "$php_bin" ]] || { warn "Binario php no encontrado en PATH; omite verificación."; return 0; }

  if "$php_bin" -m 2>/dev/null | grep -qix mbstring; then
    ok "Verificado: el módulo mbstring está activo en $("$php_bin" -v | head -1)."
  else
    die "mbstring no aparece en 'php -m'. Revisa la instalación manualmente."
  fi
}

main() {
  require_root "$@"
  info "Instalador de PHP ${PHP_VER} mbstring — Debian ${TARGET_DEBIAN_MAJOR} Bullseye amd64"
  check_system
  gather_debs
  install_debs
  verify_install
  ok "Todo listo."
}

main "$@"
