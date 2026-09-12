# WireGuard Web Console

这是下一阶段 Web Console 的 MVP 设计说明。

## 目标

把现有 VPS 脚本包装成一个简单的管理页面：

- 查看服务状态
- 查看客户端列表
- 添加客户端
- 删除客户端
- 查看客户端配置 / 二维码
- 查看 `doctor.sh` 健康检查结果

## 设计原则

- Web Console 运行在 VPS 本机
- 不直接修改 WireGuard 配置格式，优先调用现有 `scripts/*.sh`
- 不在 GitHub 保存任何私钥或客户端配置
- 管理页面必须经过认证
- MVP 默认只允许通过 SSH 隧道或本机反向代理访问，避免直接暴露管理端口到公网

## 后续实现

建议技术栈：

- Python
- Flask
- systemd
- 现有 Bash scripts 作为后端操作层

第一版只实现只读状态 + 客户端管理，不加入复杂账号系统、数据库或多用户权限。