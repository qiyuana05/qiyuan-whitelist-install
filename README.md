# 长安启源车机 · 白名单安装与签名

> 记录长安启源车机（C589 PHEV / 启源 OS / Android 9）上，**为什么官方的 APK 能装、
> 自己签名的装不上**，以及如何按车机的校验规则给自己的应用签名。
>
> **适用版本**：启源 OS（Android 9 / API 28），2026-08 ~ 2026-10 实车验证。
> 其他年款、配置或 OTA 版本可能不同，请以你的车为准。

---

## 一句话结论

车机的"白名单"不是一个东西，而是**两道独立的门**：

| 门 | 校验什么 | 在哪校验 | 失败后果 |
|---|---|---|---|
| **安装门** | APK 签名证书的 **序列号** | `CertificateManager.isCheckAuth()` | 装不上 |
| **卸载门** | 包名是否在服务器签名的 `whitelist.json` | `WhiteListHelper.checkWhiteList()` | 装上了也卸不掉 |

关键点：

- 安装门**只比对序列号**，不校验公钥、指纹、DN。所以自签一张同序列号的证书就能过；
- 卸载门是**服务器 RSA 签名保护的包名列表**，不是"包名规则"，改包名不能绕过；
- 两道门互不影响：签对序列号能装，但能不能卸是另一回事。

**本仓库讲清楚机制和实现步骤，但不提供任何真实证书序列号、私钥、keystore 或完整的
白名单包名清单。** 这些需要你从自己的车机上提取。

---

## 快速开始

```bash
# 1) 从你自己车机的官方 APK 提取目标序列号
bash examples/check_cert.sh /path/to/official.apk

# 2) 用该序列号生成自签证书
bash examples/gen_whitelist_cert.sh <TARGET_SERIAL> [TARGET_DN]

# 3) 对齐 + 签名
bash examples/sign_apk.sh input-unsigned.apk output-signed.apk

# 4) 验证序列号
bash examples/check_cert.sh output-signed.apk
```

详细步骤与原理：[docs/03-实现-一步步做白名单签名.md](docs/03-实现-一步步做白名单签名.md)。

---

## 文档导航

| 文档 | 内容 |
|---|---|
| [docs/00-背景-两道门.md](docs/00-背景-两道门.md) | 安装门 / 卸载门的区别与关系 |
| [docs/01-发现-怎么定位到序列号校验.md](docs/01-发现-怎么定位到序列号校验.md) | 从"装不上"到定位 `isCheckAuth` 的完整过程 |
| [docs/02-原理-两道门的校验逻辑.md](docs/02-原理-两道门的校验逻辑.md) | 序列号比对、白名单 RSA 验签、为什么改包名没用 |
| [docs/03-实现-一步步做白名单签名.md](docs/03-实现-一步步做白名单签名.md) | 提取序列号、生成证书、zipalign、apksigner、验证 |
| [docs/04-验证记录.md](docs/04-验证记录.md) | 实车验证结果、踩过的坑、失败案例 |
| [docs/05-风险与恢复.md](docs/05-风险与恢复.md) | 装不上/卸不掉/覆盖失败分别怎么处理 |

## 仓库结构

```
qiyuan-whitelist-install/
├── README.md
├── docs/
│   ├── 00-背景-两道门.md
│   ├── 01-发现-怎么定位到序列号校验.md
│   ├── 02-原理-两道门的校验逻辑.md
│   ├── 03-实现-一步步做白名单签名.md
│   ├── 04-验证记录.md
│   └── 05-风险与恢复.md
├── examples/
│   ├── README.md
│   ├── check_cert.sh              ← 查看 APK 证书序列号
│   ├── gen_whitelist_cert.sh      ← 按目标序列号生成自签证书
│   └── sign_apk.sh                ← 对齐 + 签名 + 验证
├── DISCLAIMER.md
├── SECURITY.md
├── LICENSE
└── .gitignore
```

---

## 适合谁看

- 自己写了车机工具，但始终装不上的开发者；
- 想知道"为什么网上教程的序列号在我车上没用"的车友；
- 想理解 `INSTALL_FAILED_UPDATE_INCOMPATIBLE`、`is auth app, not allow delete!`
  这些报错背后机制的人。

如果你只想装卸载门，那不是签名问题，先看
[docs/02-原理-两道门的校验逻辑.md](docs/02-原理-两道门的校验逻辑.md) 的第 2 节。

---

## 免责声明（摘要）

- 仅在你拥有或获明确授权的车辆上操作；
- 伪造序列号签名会绕过厂商的安装校验，可能违反服务条款、影响保修与 OTA；
- 不同车型/平台的序列号不同，照抄别人的值不会生效，也可能带来风险；
- 作者不对任何损失负责。完整条款见 [DISCLAIMER.md](DISCLAIMER.md)。

## 许可证

- 文档：CC BY-NC-SA 4.0
- 示例代码：MIT

> 文中提及的第三方应用、证书、商标与协议归各自权利人所有。本仓库不包含任何
> 真实签名私钥、keystore、证书序列号或白名单原始数据。