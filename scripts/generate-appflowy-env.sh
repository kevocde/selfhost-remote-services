#!/usr/bin/env bash
#
# Generates docker/appflowy/.env from docker/appflowy/.env-example with
# freshly generated random secrets.
#
# Usage:
#   bash scripts/generate-appflowy-env.sh            # fails if .env already exists
#   bash scripts/generate-appflowy-env.sh --force    # regenerate (replaces current values)
#   bash scripts/generate-appflowy-env.sh --help
#
# The root .env / .env-example are NOT touched.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE="${PROJECT_DIR}/docker/appflowy/.env-example"
TARGET="${PROJECT_DIR}/docker/appflowy/.env"

FORCE=0

usage() {
  sed -n '2,11p' "$0"
  exit 0
}

for arg in "$@"; do
  case "${arg}" in
    --force) FORCE=1 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: ${arg}" >&2; exit 1 ;;
  esac
done

if [[ ! -f "${TEMPLATE}" ]]; then
  echo "ERROR: template not found: ${TEMPLATE}" >&2
  exit 1
fi

if [[ -f "${TARGET}" && "${FORCE}" -ne 1 ]]; then
  echo "ERROR: ${TARGET} already exists." >&2
  echo "       Use --force to regenerate (existing values will be replaced)." >&2
  exit 1
fi

# rand_hex <bytes> -> hex string of 2*<bytes> chars (alphanumeric, URL-safe)
rand_hex() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "$1"
  else
    head -c "$1" /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

POSTGRES_PASSWORD="$(rand_hex 16)"   # 32 chars
MINIO_ACCESS_KEY="$(rand_hex 10)"    # 20 chars (MinIO max)
MINIO_SECRET_KEY="$(rand_hex 20)"    # 40 chars (MinIO max)
ADMIN_PASSWORD="$(rand_hex 12)"      # 24 chars
JWT_SECRET="$(rand_hex 32)"          # 64 chars

mkdir -p "$(dirname "${TARGET}")"

sed \
  -e "s|^POSTGRES_PASSWORD=CHANGE_ME$|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|" \
  -e "s|postgres://postgres:CHANGE_ME@|postgres://postgres:${POSTGRES_PASSWORD}@|g" \
  -e "s|^MINIO_ROOT_USER=CHANGE_ME$|MINIO_ROOT_USER=${MINIO_ACCESS_KEY}|" \
  -e "s|^MINIO_ROOT_PASSWORD=CHANGE_ME$|MINIO_ROOT_PASSWORD=${MINIO_SECRET_KEY}|" \
  -e "s|^APPFLOWY_S3_ACCESS_KEY=CHANGE_ME$|APPFLOWY_S3_ACCESS_KEY=${MINIO_ACCESS_KEY}|" \
  -e "s|^APPFLOWY_S3_SECRET_KEY=CHANGE_ME$|APPFLOWY_S3_SECRET_KEY=${MINIO_SECRET_KEY}|" \
  -e "s|^GOTRUE_ADMIN_PASSWORD=CHANGE_ME$|GOTRUE_ADMIN_PASSWORD=${ADMIN_PASSWORD}|" \
  -e "s|^GOTRUE_JWT_SECRET=CHANGE_ME_LONG$|GOTRUE_JWT_SECRET=${JWT_SECRET}|" \
  -e "s|^APPFLOWY_GOTRUE_JWT_SECRET=SAME_AS_GOTRUE_JWT_SECRET$|APPFLOWY_GOTRUE_JWT_SECRET=${JWT_SECRET}|" \
  "${TEMPLATE}" > "${TARGET}"

chmod 600 "${TARGET}"

if grep -Eq 'CHANGE_ME|SAME_AS_GOTRUE_JWT_SECRET' "${TARGET}"; then
  echo "ERROR: some placeholders were not replaced in ${TARGET}" >&2
  exit 1
fi

echo "Generated ${TARGET} with fresh secrets."
echo "Review GOTRUE_ADMIN_EMAIL (and SMTP settings) in ${TARGET} if needed."
