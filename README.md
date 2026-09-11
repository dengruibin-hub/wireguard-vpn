# WireGuard VPN

一个用于个人远程访问和网络隐私保护的 WireGuard VPN 项目。

## 项目结构

- `scripts/install-server.sh` — Ubuntu/Debian VPS 一键安装服务端
- `scripts/add-client.sh` — 添加客户端并生成配置
- `scripts/remove-client.sh` — 删除客户端
- `scripts/show-client.sh` — 显示客户端配置；安装 `qrencode` 后可输出二维码
- `configs/` — 本地生成配置目录（默认不提交敏感配置）

## 当前架构

```text
手机 / iPad / 笔记本
        │
   WireGuard UDP
        │ 51820
        ▼
      VPS
   10.66.66.1/24
        │
   NAT / IPv4 Full Tunnel
        ▼
     Internet
```

当前版本为 **IPv4 全隧道**。服务端默认禁止 VPN 客户端之间互相转发，降低单个客户端被入侵后的横向移动风险。

## 快速开始

### 1. 准备 VPS

推荐 Ubuntu 22.04/24.04 或兼容的 Debian 系统，并确保 VPS 有公网 IPv4 地址。

在 VPS 上下载项目后执行：

```bash
sudo bash scripts/install-server.sh
```

默认配置：

- WireGuard UDP：`51820`
- VPN 网段：`10.66.66.0/24`
- 服务端地址：`10.66.66.1/24`

如果希望固定域名或公网 IP，可在创建客户端时设置：

```bash
sudo WG_ENDPOINT=vpn.example.com bash scripts/add-client.sh phone
```

### 2. 添加客户端

```bash
sudo bash scripts/add-client.sh phone
```

生成的客户端配置位于：

```text
/etc/wireguard/clients/phone.conf
```

将该配置导入 WireGuard 官方客户端即可。

### 3. 查看客户端配置

```bash
sudo bash scripts/show-client.sh phone
```

如果服务器安装了 `qrencode`，该命令还会显示终端二维码，方便手机导入。

### 4. 删除客户端

```bash
sudo bash scripts/remove-client.sh phone
```

## 运维检查

查看 WireGuard 状态：

```bash
sudo wg show
sudo systemctl status wg-quick@wg0
```

查看监听端口：

```bash
sudo ss -lunp | grep 51820
```

## 安全注意事项

- **不要**把任何私钥、完整客户端配置或服务器实际配置提交到公开 GitHub 仓库。
- 客户端配置包含私钥，应妥善保管；泄露后应删除该客户端并重新生成密钥。
- 建议服务器上的 `/etc/wireguard` 和配置文件权限保持严格限制。
- 当前版本只覆盖 IPv4 全隧道；如果客户端所在网络启用 IPv6，IPv6 流量可能不经过该 VPN。生产使用前建议增加 IPv6 隧道或明确关闭/隔离 IPv6。
- VPS 的安全组/云防火墙需要允许 UDP `51820` 入站。
- 仅在你拥有或获授权管理的服务器和设备上使用。
