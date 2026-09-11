# WireGuard VPN

一个用于个人远程访问和网络隐私保护的 WireGuard VPN 项目。

## 项目结构

- `scripts/install-server.sh` — Ubuntu VPS 一键安装服务端
- `scripts/add-client.sh` — 添加客户端并生成配置
- `scripts/remove-client.sh` — 删除客户端
- `scripts/show-client.sh` — 显示客户端配置
- `configs/` — 本地生成配置目录（默认不提交敏感配置）

## 快速开始

### 1. 准备 VPS

推荐 Ubuntu 22.04/24.04，并确保 VPS 有公网 IPv4 地址。

在 VPS 上下载项目后执行：

```bash
sudo bash scripts/install-server.sh
```

默认配置：

- WireGuard UDP：`51820`
- VPN 网段：`10.66.66.0/24`
- 服务端地址：`10.66.66.1/24`

### 2. 添加客户端

```bash
sudo bash scripts/add-client.sh phone
```

生成的客户端配置位于：

```text
/etc/wireguard/clients/phone.conf
```

将该配置导入 WireGuard 客户端即可。

### 3. 删除客户端

```bash
sudo bash scripts/remove-client.sh phone
```

## 安全注意事项

- **不要**把任何私钥、完整客户端配置或服务器实际配置提交到公开 GitHub 仓库。
- 客户端配置包含私钥，应妥善保管。
- 建议服务器上的配置文件权限为 `600`。
- 仅在你拥有或获授权管理的服务器和设备上使用。
