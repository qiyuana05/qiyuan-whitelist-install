#!/usr/bin/env bash
# 对齐 + 签名 + 验证
#
# 用法:
#   bash sign_apk.sh <input-unsigned.apk> [output-signed.apk]
#
# 环境变量:
#   KS_FILE   keystore 路径（默认 ./my-car.p12）
#   KS_ALIAS  key alias（默认 cert）
#   KS_PASS   keystore 口令（不设则交互提示）
#   BUILD_TOOLS  build-tools 目录（用于找 zipalign / apksigner）
set -euo pipefail

IN_APK="${1:?用法: bash sign_apk.sh <input-unsigned.apk> [output] }"
OUT_APK="${2:-${IN_APK%.apk}-signed.apk}"

KS_FILE="${KS_FILE:-$(cd "$(dirname "$0")" && pwd)/my-car.p12}"
KS_ALIAS="${KS_ALIAS:-cert}"

if [ ! -f "$IN_APK" ]; then
  echo "找不到输入 APK: $IN_APK" >&2
  exit 1
fi
if [ ! -f "$KS_FILE" ]; then
  echo "找不到 keystore: $KS_FILE" >&2
  echo "先运行: bash gen_whitelist_cert.sh <TARGET_SERIAL> \"<TARGET_DN>\"" >&2
  exit 1
fi

# 定位 build-tools
if [ -z "${BUILD_TOOLS:-}" ]; then
  if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME/build-tools" ]; then
    BUILD_TOOLS="$(ls -d "$ANDROID_HOME"/build-tools/* 2>/dev/null | sort -V | tail -1)"
  elif [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -d "$ANDROID_SDK_ROOT/build-tools" ]; then
    BUILD_TOOLS="$(ls -d "$ANDROID_SDK_ROOT"/build-tools/* 2>/dev/null | sort -V | tail -1)"
  fi
fi

ZIPALIGN="${ZIPALIGN:-${BUILD_TOOLS:-}/zipalign}"
APKSIGNER="${APKSIGNER:-${BUILD_TOOLS:-}/apksigner}"

# Windows 下可执行文件带 .exe / .bat
if [ ! -x "$ZIPALIGN" ] && [ -x "${ZIPALIGN}.exe" ]; then ZIPALIGN="${ZIPALIGN}.exe"; fi
if [ ! -x "$APKSIGNER" ] && [ -x "${APKSIGNER}.bat" ]; then APKSIGNER="${APKSIGNER}.bat"; fi

if [ ! -x "$ZIPALIGN" ]; then
  echo "找不到 zipalign。请设置 BUILD_TOOLS 或把 build-tools 加入 PATH。" >&2
  exit 1
fi
if [ ! -x "$APKSIGNER" ]; then
  echo "找不到 apksigner。请设置 BUILD_TOOLS 或把 build-tools 加入 PATH。" >&2
  exit 1
fi

TMP_ALIGNED="$(mktemp "${TMPDIR:-/tmp}/align_XXXXXX.apk")"
trap 'rm -f "$TMP_ALIGNED"' EXIT

echo "[1/3] zipalign ..."
"$ZIPALIGN" -f 4 "$IN_APK" "$TMP_ALIGNED"

echo "[2/3] apksigner sign ..."
SIGN_ARGS=(sign --ks "$KS_FILE" --ks-key-alias "$KS_ALIAS"
  --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true
  --out "$OUT_APK" "$TMP_ALIGNED")

if [ -n "${KS_PASS:-}" ]; then
  "$APKSIGNER" "${SIGN_ARGS[@]}" --ks-pass "pass:${KS_PASS}"
else
  echo "未设置 KS_PASS，apksigner 会交互提示输入口令。"
  "$APKSIGNER" "${SIGN_ARGS[@]}"
fi

echo "[3/3] verify ..."
"$APKSIGNER" verify --print-certs "$OUT_APK" | \
  grep -Ei "Signer #1 certificate (DN|serial|SHA-256)|Verified" || true

echo
echo "完成: $OUT_APK"
echo "请确认上面的 serial number 与目标车机一致。"