#!/usr/bin/env bash
# 按目标序列号生成自签证书与 PKCS12 keystore
#
# 用法:
#   bash gen_whitelist_cert.sh <TARGET_SERIAL> "<TARGET_DN>"
#
# 示例:
#   bash gen_whitelist_cert.sh 0a1b2c3d4e5f6071 "/C=CN/ST=State/L=City/O=Example/OU=Unit/CN=Example"
#
# 说明:
#   - TARGET_SERIAL 必须是十六进制，可带或不带 0x 前缀；
#   - 生成的 private.key / my-car.p12 是你的签名身份，不要提交或外发；
#   - keystore 口令通过环境变量 KS_PASS 传入，交互输入也可以。
set -euo pipefail

SERIAL_RAW="${1:?用法: bash gen_whitelist_cert.sh <TARGET_SERIAL> \"<TARGET_DN>\"}"
DN_RAW="${2:?请提供 DN，例如 /C=CN/ST=State/L=City/O=Example/OU=Unit/CN=Example}"

# 统一成 0x 十六进制
SERIAL_CLEAN="$(printf '%s' "$SERIAL_RAW" | tr -d ' :' | tr '[:upper:]' '[:lower:]')"
SERIAL_CLEAN="${SERIAL_CLEAN#0x}"
if ! printf '%s' "$SERIAL_CLEAN" | grep -Eq '^[0-9a-f]+$'; then
  echo "序列号格式不正确：$SERIAL_RAW（应为十六进制）" >&2
  exit 1
fi
SERIAL="0x${SERIAL_CLEAN}"

OUT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$OUT_DIR"

for f in private.key csr.csr certificate.crt my-car.p12; do
  if [ -f "$f" ]; then
    echo "已存在 $f，为避免覆盖，先退出。要重新生成请手动删除。" >&2
    exit 1
  fi
done

echo "[1/4] 生成 RSA 私钥 ..."
openssl genrsa -out private.key 2048
chmod 600 private.key 2>/dev/null || true

echo "[2/4] 生成 CSR ..."
openssl req -new -key private.key -out csr.csr -subj "$DN_RAW"

echo "[3/4] 自签证书（serial=$SERIAL，有效期 10 年）..."
openssl x509 -req -in csr.csr -signkey private.key \
  -out certificate.crt -days 3650 -set_serial "$SERIAL"

echo "[4/4] 打包 PKCS12 ..."
if [ -n "${KS_PASS:-}" ]; then
  openssl pkcs12 -export \
    -in certificate.crt -inkey private.key \
    -out my-car.p12 -name cert -passout "pass:${KS_PASS}"
else
  echo "未设置 KS_PASS，接下来会交互提示设置 keystore 口令。"
  openssl pkcs12 -export \
    -in certificate.crt -inkey private.key \
    -out my-car.p12 -name cert
fi

echo
echo "===== 生成的证书信息 ====="
keytool -printcert -file certificate.crt | \
  grep -Ei "Owner|Issuer|Serial number|Valid from" || true

echo
echo "完成："
echo "  private.key       — 私钥，务必保密"
echo "  certificate.crt   — 自签证书"
echo "  my-car.p12        — 签名用 keystore（alias: cert）"
echo
echo "下一步："
echo "  bash sign_apk.sh input-unsigned.apk output-signed.apk"
echo
echo "提醒："
echo "  - 序列号必须来自你自己的车机，不要照抄别人；"
echo "  - 不要把 private.key / my-car.p12 提交到仓库。"