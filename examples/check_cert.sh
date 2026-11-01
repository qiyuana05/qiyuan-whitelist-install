#!/usr/bin/env bash
# 查看 APK 的签名证书信息（DN / 序列号 / 有效期）
# 用法: bash check_cert.sh <apk>
set -euo pipefail

APK="${1:?用法: bash check_cert.sh <apk>}"

if [ ! -f "$APK" ]; then
  echo "找不到文件: $APK" >&2
  exit 1
fi

echo "===== keytool ====="
keytool -printcert -jarfile "$APK" 2>/dev/null | \
  grep -Ei "Owner|Issuer|Serial number|Valid from" || true

echo
echo "===== apksigner ====="
if command -v apksigner >/dev/null 2>&1; then
  apksigner verify --print-certs "$APK" 2>/dev/null | \
    grep -Ei "Signer #1 certificate (DN|serial|SHA-256)|Verified" || true
else
  echo "未找到 apksigner，跳过（可把 build-tools 目录加入 PATH）"
fi

echo
echo "提示：安装门只看 serial number，不看 DN 或指纹。"