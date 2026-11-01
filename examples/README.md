# 示例脚本

> 三个脚本覆盖"查证书 → 生成证书 → 签名"的完整流程。
>
> 所有脚本都不含真实序列号、DN、私钥或口令，全部通过参数/环境变量传入。
> 仅在你拥有或获授权的车辆上使用。

## 文件

| 文件 | 用途 |
|---|---|
| `check_cert.sh` | 查看 APK 的证书 DN / 序列号 / 有效期 |
| `gen_whitelist_cert.sh` | 按目标序列号生成自签证书与 `my-car.p12` |
| `sign_apk.sh` | zipalign + apksigner 签名 + 验证 |

运行产物（不提交、已加入 `.gitignore`）：

```
private.key
csr.csr
certificate.crt
my-car.p12
*-signed.apk
```

## 完整流程

```bash
cd examples

# 1) 从自己车机的官方 APK 提取序列号
bash check_cert.sh /path/to/official.apk
#   记下 Serial number（十六进制）

# 2) 生成证书（DN 可照抄官方包的 Owner，也可自拟）
export KS_PASS='your-password'
bash gen_whitelist_cert.sh <TARGET_SERIAL> "/C=CN/ST=State/L=City/O=Example/OU=Unit/CN=Example"

# 3) 签名
bash sign_apk.sh ../path/to/app-unsigned.apk ../path/to/app-signed.apk

# 4) 再验证一次
bash check_cert.sh ../path/to/app-signed.apk

# 5) 安装
adb install -r ../path/to/app-signed.apk
```

## 环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `KS_PASS` | 无（交互输入） | keystore 口令 |
| `KS_FILE` | `./my-car.p12` | keystore 路径 |
| `KS_ALIAS` | `cert` | key alias |
| `BUILD_TOOLS` | 自动探测 `$ANDROID_HOME/build-tools` | build-tools 目录 |
| `ANDROID_HOME` | 无 | Android SDK 根目录 |

## 常见问题

| 现象 | 原因 | 处理 |
|---|---|---|
| `找不到 zipalign` | 未设置 `BUILD_TOOLS` | `export BUILD_TOOLS=$ANDROID_HOME/build-tools/35.0.1` |
| `序列号格式不正确` | 传了十进制或带冒号 | 用十六进制，去掉 `:` 和空格 |
| `已存在 private.key` | 上一次生成过 | 先备份/删除旧文件，脚本不会覆盖 |
| 签名后装不上 | 序列号不匹配 | 重新提取目标序列号，或检查 `-set_serial` |
| 签名成功但 `Verified` 为 false | 对齐/签名顺序错 | 先 zipalign 再签名 |

## 安全提醒

- `private.key` 和 `my-car.p12` 是你的签名身份，泄露后别人可以冒用；
- 不要把这两个文件提交到任何仓库或发给别人；
- 不要给来源不明的 APK 签名——你等于在为它背书；
- 签对序列号后，应用会更难卸载，先看
  [05-风险与恢复](../docs/05-风险与恢复.md)。