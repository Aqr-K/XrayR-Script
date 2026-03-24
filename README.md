# XrayR-Script

XrayR 安装和配置脚本库

## 脚本清单

- **install.sh** - XrayR 安装脚本 (包含反识别化参数支持)
- **migrate.sh** - XrayR 迁移脚本 (用于改变二进制名称、进程名、安装路径等)

---

## 快速开始 (Quick Start)

### 基础安装

```bash
curl -fsSL https://raw.githubusercontent.com/Aqr-K/XrayR-Script/main/install.sh | bash -s -- \
--xrayr-repo https://github.com/{OWNER}/{REPO} \
--xrayr-token {YOUR_PRIVATE_XRAYR_PLUS_TOKEN}
```

### 自定义部署 (反识别化)

```bash
curl -fsSL https://raw.githubusercontent.com/Aqr-K/XrayR-Script/main/install.sh | bash -s -- \
--xrayr-repo https://github.com/{OWNER}/{REPO} \
--bin-name cdn-service \
--process-name nginx \
--xrayr-install-path /opt/cdn \
--config-install-path /etc/cdn
```

---

## 参数说明

### install.sh 参数

**必选参数：**
- `-rr, --xrayr-repo URL` - XrayR 源码仓库地址

**可选参数：**
- `-b, --bin-name NAME` - 自定义二进制文件名 (默认: XrayR)
- `-p, --process-name NAME` - 自定义启动进程名 (默认: XrayR)
- `-rp, --xrayr-install-path PATH` - 安装路径 (默认: /usr/local/XrayR)
- `-cp, --config-install-path PATH` - 配置路径 (默认: /etc/XrayR)
- `-rt, --xrayr-token TOKEN` - XrayR 仓库访问令牌
- `-rv, --xrayr-version VERSION` - 指定安装版本 (默认: latest)
- `-cr, --config-repo URL` - 配置文件仓库地址
- `-ct, --config-token TOKEN` - 配置仓库访问令牌
- `-a, --acme` - 安装 ACME.sh 用于 TLS 证书
- `-m, --mode MODE` - 安装模式 (install/update-core/update-config/update-geo)
- `-t, --token TOKEN` - 全局 GitHub 访问令牌
- `-d, --debug` - 启用调试模式
- `-h, --help` - 显示帮助信息

### migrate.sh 参数

读取旧配置并迁移到新位置/名称

**可选参数：**
- `--config-file PATH` - 指定 .install_config 文件路径
- `-b, --to-bin-name NAME` - 新二进制文件名
- `-p, --to-process-name NAME` - 新进程名
- `-i, --to-install-path PATH` - 新安装路径
- `-c, --to-config-path PATH` - 新配置路径
- `--confirm` - 显示确认对话 (默认直接执行)
- `-d, --debug` - 启用调试模式
- `-h, --help` - 显示帮助信息

---

## 使用示例

### 示例1: 标准部署

```bash
bash install.sh \
  --xrayr-repo https://github.com/XTLS/XrayR \
  --config-repo https://github.com/myconfig/repo
```

### 示例2: 隐蔽部署 (改进程名)

```bash
bash install.sh \
  --xrayr-repo https://github.com/XTLS/XrayR \
  --bin-name my-app \
  --process-name worker
```

### 示例3: 批量服务器部署

```bash
for server in server1 server2 server3; do
  ssh $server << 'EOF'
    curl -fsSL https://raw.githubusercontent.com/Aqr-K/XrayR-Script/main/install.sh | bash -s -- \
    --xrayr-repo https://github.com/XTLS/XrayR \
    --bin-name service-$HOSTNAME \
    --process-name worker-$HOSTNAME \
    --xrayr-install-path /opt/app \
    --config-install-path /etc/app
EOF
done
```

### 示例4: 迁移现有部署

```bash
# 改变进程名（其他参数保持不变）
sudo bash migrate.sh --to-process-name apache

# 完全迁移到新位置
sudo bash migrate.sh \
  --to-bin-name newservice \
  --to-process-name newworker \
  --to-install-path /opt/newapp \
  --to-config-path /etc/newapp
```

---

## 工作流程

### 安装流程 (install.sh)

1. 检查并安装系统依赖
2. 解析 XrayR 仓库信息
3. 下载并解压 XrayR 二进制文件
4. **重命名为自定义二进制名** ✨
5. 下载 geoip/geosite 数据
6. 安装配置文件 (可选)
7. **使用 exec -a 伪装进程名** ✨
8. 配置开机自启服务
9. 启动服务

### 迁移流程 (migrate.sh)

1. 读取旧配置 (.install_config)
2. 停止现有服务
3. 迁移二进制文件到新位置/名称
4. 迁移配置文件 (可选)
5. **更新 systemd/OpenRC/launchd 服务配置** ✨
6. 启动新服务

---

## 配置文件

安装后，脚本会在配置目录创建 `.install_config` 文件，记录所有安装参数：

```bash
# /etc/XrayR/.install_config (或自定义配置路径)
XRAY_BIN_NAME="custom-name"
XRAY_INSTALL_PATH="/custom/path"
XRAY_CONFIG_PATH="/custom/config"
XRAY_PROCESS_NAME="custom-process"
INSTALL_TIMESTAMP="2024-03-24T02:36:00Z"
```

此文件用于：
- 迁移脚本自动检测旧配置
- 管理脚本识别正确的二进制位置
- 系统重启后正确启动服务

---

## 支持的平台

- ✅ **Linux (systemd)** - Debian, Ubuntu, CentOS, RHEL 等
- ✅ **Linux (OpenRC)** - Alpine, Gentoo 等
- ✅ **macOS (launchd)** - 通过 launchd 实现开机自启
- ✅ **FreeBSD/DragonFly (rc.d)** - Server BSD 系统
- ✅ **OpenBSD (rc.d)** - OpenBSD 专有配置
- ✅ **Termux (termux-services)** - Android Termux 环境

- ❌ **Windows** - 脚本不支持 Windows

---

## 故障排查

### 查看安装配置

```bash
cat /etc/XrayR/.install_config
```

### 查看服务状态

```bash
systemctl status XrayR
journalctl -u XrayR -f
```

### 重新迁移到旧配置

```bash
sudo bash migrate.sh \
  --to-bin-name XrayR \
  --to-process-name XrayR \
  --to-install-path /usr/local/XrayR \
  --to-config-path /etc/XrayR
```

---

## 📄 许可证 (License)

本项目采用 [MIT License](https://opensource.org/licenses/MIT) 授权。
