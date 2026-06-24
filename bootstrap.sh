#!/bin/bash
# scripts/bootstrap.sh — Public launcher cho Ajax Monitor installer
# Repo public: tpofastconnect-max/ajax-monitor-bootstrap
# Chạy: bash <(curl -sSL https://raw.githubusercontent.com/tpofastconnect-max/ajax-monitor-bootstrap/main/bootstrap.sh)
set -euo pipefail

PRIVATE_REPO="tpofastconnect-max/ajax-monitor"
BRANCH="master"
TOKEN_FILE="$HOME/.config/ajax-monitor/.gh_token"

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
step() { echo -e "\n${BLUE}▶${NC} $1"; }

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║        AJAX MONITOR — BOOTSTRAP              ║"
echo "╚══════════════════════════════════════════════╝"
echo ""


# ── BƯỚC 1: Đọc GitHub Token ─────────────────────────────────────────────────
step "BƯỚC 1 — Đọc GitHub Token"

GH_TOKEN=""

if [ -f "$TOKEN_FILE" ]; then
  PERMS=$(stat -c "%a" "$TOKEN_FILE")
  if [ "$PERMS" != "600" ]; then
    err "File $TOKEN_FILE tồn tại nhưng permission là $PERMS (cần 600)\nSửa: chmod 600 $TOKEN_FILE"
  fi
  GH_TOKEN=$(tr -d '[:space:]' < "$TOKEN_FILE")
  log "Đọc token từ $TOKEN_FILE"
else
  warn "Không tìm thấy $TOKEN_FILE"
  echo ""
  echo "  Để bỏ qua hỏi token lần sau, tạo file:"
  echo "    mkdir -p ~/.config/ajax-monitor"
  echo "    echo 'ghp_...' > $TOKEN_FILE"
  echo "    chmod 600 $TOKEN_FILE"
  echo ""
  read -rsp "  Paste GitHub Fine-grained PAT: " GH_TOKEN
  echo ""
fi

[ -z "$GH_TOKEN" ] && err "Token rỗng"

# ── BƯỚC 2: Validate token ────────────────────────────────────────────────────
step "BƯỚC 2 — Kiểm tra token với GitHub API"

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$PRIVATE_REPO")

case "$HTTP_STATUS" in
  200) log "Token hợp lệ — repo $PRIVATE_REPO OK" ;;
  401) err "Token không hợp lệ hoặc đã hết hạn" ;;
  403) err "Token không có quyền truy cập repo $PRIVATE_REPO" ;;
  404) err "Không tìm thấy repo $PRIVATE_REPO — kiểm tra scope Contents: Read-only" ;;
  *)   err "GitHub API trả về HTTP $HTTP_STATUS — kiểm tra kết nối internet" ;;
esac

# ── BƯỚC 3: Chọn loại cài đặt ────────────────────────────────────────────────
step "BƯỚC 3 — Chọn loại cài đặt"
echo ""
echo "  [B] Pi nhà / Dev  — cài đầy đủ, có git, research mode"
echo "  [C] Pi khách      — production, kiosk hardening, ẩn tab Research"
echo ""
read -rp "  Chọn [B/C]: " INSTALL_TYPE

case "${INSTALL_TYPE^^}" in
  B) SCRIPT_PATH="scripts/install.sh" ;;
  C) SCRIPT_PATH="scripts/install-customer.sh" ;;
  *) err "Chỉ chấp nhận B hoặc C" ;;
esac

# ── BƯỚC 4: Tải installer về /tmp ────────────────────────────────────────────
step "BƯỚC 4 — Tải $SCRIPT_PATH"

TMP_SCRIPT=$(mktemp /tmp/ajax-install-XXXXXX.sh)
trap 'rm -f "$TMP_SCRIPT"' EXIT

HTTP_STATUS=$(curl -s -o "$TMP_SCRIPT" -w "%{http_code}" \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github.raw+json" \
  "https://api.github.com/repos/$PRIVATE_REPO/contents/$SCRIPT_PATH?ref=$BRANCH")

[ "$HTTP_STATUS" != "200" ] && err "Tải $SCRIPT_PATH thất bại (HTTP $HTTP_STATUS)"
[ ! -s "$TMP_SCRIPT" ]      && err "File tải về rỗng"

chmod +x "$TMP_SCRIPT"
log "Tải $SCRIPT_PATH OK"

# ── BƯỚC 5: Chạy installer ────────────────────────────────────────────────────
step "BƯỚC 5 — Chạy installer"
echo ""

export GH_TOKEN
bash "$TMP_SCRIPT"

unset GH_TOKEN
