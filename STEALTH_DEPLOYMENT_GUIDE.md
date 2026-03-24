# 隐蔽部署指南 (Stealth Deployment Guide)

本指南覆盖从标准 XrayR 安装迁移到完全隐蔽部署的详细步骤。

---

## 场景 1：从无 .install_config 的旧安装迁移到隐蔽部署

### 前提条件
- 旧安装：`/usr/local/XrayR/XrayR`（二进制） + `/etc/XrayR/`（配置）
- 没有 `.install_config` 文件
- 想要迁移到隐蔽部署（自定义所有参数）

### 完整步骤

#### Step 1: 检查旧安装状态
```bash
# 检查旧二进制文件
ls -la /usr/local/XrayR/

# 检查旧配置文件
ls -la /etc/XrayR/

# 检查旧 service
systemctl status xrayr
```

#### Step 2: 运行迁移脚本，指定旧配置 + 新隐蔽参数

假设：
- **旧安装**：默认路径 `/usr/local/XrayR` + `/etc/XrayR`
- **新隐蔽部署**：二进制名 `cdn-service`，进程名 `nginx`，安装路径 `/opt/cdn`，配置路径 `/etc/cdn`，service 名 `cdn`

```bash
sudo bash migrate.sh \
  --old-bin-name XrayR \
  --old-install-path /usr/local/XrayR \
  --old-config-path /etc/XrayR \
  --old-process-name XrayR \
  --old-service-name xrayr \
  --to-bin-name cdn-service \
  --to-process-name nginx \
  --to-install-path /opt/cdn \
  --to-config-path /etc/cdn \
  --to-service-name cdn
```

**脚本执行流程：**
1. ✅ 读取旧配置（从参数）
2. ✅ 验证旧二进制存在：`/usr/local/XrayR/XrayR`
3. ✅ 停止旧 service：`systemctl stop xrayr`
4. ✅ 迁移二进制：`cp /usr/local/XrayR/XrayR → /opt/cdn/cdn-service`
5. ✅ 迁移配置：`cp -r /etc/XrayR/* → /etc/cdn/`
6. ✅ 生成 `.install_config`：`/etc/cdn/.install_config`（包含新的隐蔽参数）
7. ✅ 清理旧 service：删除 `/etc/systemd/system/xrayr.service`
8. ✅ 启动新 service：`systemctl restart cdn`

#### Step 3: 验证迁移结果

```bash
# 检查新二进制
ls -la /opt/cdn/cdn-service

# 检查新配置和 .install_config
ls -la /etc/cdn/

# 查看 .install_config 内容
cat /etc/cdn/.install_config

# 检查新 service 状态
systemctl status cdn

# 查看进程名（应为 nginx）
ps aux | grep nginx
```

---

## 场景 2：从有 .install_config 的旧安装迁移到不同的隐蔽参数

### 前提条件
- 旧安装已有 `.install_config`（比如已经是自定义的）
- 想要再次迁移到新的隐蔽参数

### 完整步骤

#### Step 1: 检查现有 .install_config
```bash
cat /etc/XrayR/.install_config
# 输出示例：
# XRAY_BIN_NAME="app-service"
# XRAY_INSTALL_PATH="/opt/app"
# XRAY_CONFIG_PATH="/etc/app"
# XRAY_PROCESS_NAME="appworker"
# XRAY_SERVICE_NAME="appservice"
```

#### Step 2: 运行迁移脚本（不需指定旧参数，自动读取）

只指定新配置参数：

```bash
sudo bash migrate.sh \
  --to-bin-name hidden-daemon \
  --to-process-name systemd-run \
  --to-install-path /usr/lib/hidden \
  --to-config-path /etc/hidden \
  --to-service-name hidden
```

**脚本执行流程：**
1. ✅ 自动从 `/etc/XrayR/.install_config` 读取旧配置
2. ✅ 验证旧二进制存在
3. ✅ 停止当前 service
4. ✅ 执行完整迁移（同场景 1 的 4-8 步）

#### Step 3: 验证

```bash
systemctl status hidden
ps aux | grep systemd-run
cat /etc/hidden/.install_config
```

---

## 场景 3：只补全 .install_config，不改变路径/名称

### 前提条件
- 旧安装没有 `.install_config`
- 想要补全 `.install_config` 以便后续管理
- **不想改变任何路径/名称**

### 完整步骤

#### Step 1: 运行迁移脚本（只指定旧配置，新配置自动继承）

```bash
sudo bash migrate.sh \
  --old-bin-name XrayR \
  --old-install-path /usr/local/XrayR \
  --old-config-path /etc/XrayR \
  --old-process-name XrayR \
  --old-service-name xrayr
```

**脚本执行流程：**
1. ✅ 读取旧配置（从参数）
2. ✅ 验证旧二进制存在
3. ✅ 新配置完全继承旧值
4. ✅ **智能检测**：发现新旧配置相同
5. ✅ **跳过 stop/restart**，只生成 `.install_config`
6. ✅ `.install_config` 生成在 `/etc/XrayR/.install_config`

**结果**：服务不中断，`.install_config` 文件已生成待用。

---

## 场景 4：自动检测旧安装（使用默认值）

### 前提条件
- 旧安装使用**完全默认配置**
- 没有 `.install_config`

### 完整步骤

#### Step 1: 运行迁移脚本（不指定任何旧参数）

```bash
sudo bash migrate.sh \
  --to-bin-name cdn \
  --to-process-name web \
  --to-install-path /opt/web
```

**脚本执行流程：**
1. ✅ 尝试读取 `/etc/XrayR/.install_config`（不存在）
2. ✅ **自动使用默认旧配置**：
   - `OLD_BIN_NAME="XrayR"`
   - `OLD_INSTALL_PATH="/usr/local/XrayR"`
   - `OLD_CONFIG_PATH="/etc/XrayR"`
3. ✅ **智能默认新配置**：用户指定了 `--to-*` 参数，所以 `NEW_CONFIG_PATH` 默认为 `/etc/XrayR`（标准位置，除非明确指定）
4. ✅ 验证二进制存在，执行迁移

---

## .install_config 存放位置规则

| 场景 | 命令 | .install_config 位置 | 说明 |
|------|------|------------------|------|
| 只补全，不改路径 | `migrate.sh --old-* (仅)` | `/etc/XrayR/.install_config` | 继承旧的配置路径 |
| 指定新配置路径 | `migrate.sh --old-* --to-config-path /etc/new` | `/etc/new/.install_config` | 使用显式指定的路径 |
| 指定新安装路径但不指定配置路径 | `migrate.sh --old-* --to-install-path /opt/new` | `/etc/XrayR/.install_config` | 智能默认（标准位置）*见下表 |
| 完全迁移所有参数 | `migrate.sh --old-* --to-install-path /opt/n --to-config-path /etc/n` | `/etc/n/.install_config` | 使用显式指定的配置路径 |

### 智能默认规则

- **用户指定了新参数**（`--to-bin-name`、`--to-install-path` 等）
  - → `NEW_CONFIG_PATH` 默认为 `/etc/XrayR`（推荐的标准位置）
  
- **用户未指定任何新参数**（只用 `--old-*`）
  - → `NEW_CONFIG_PATH` 继承 `OLD_CONFIG_PATH`（保持原有位置）

---

## 服务迁移流程和停机时间

### 完整迁移时的流程（配置改变）

```
1. 停止旧 service (systemctl stop xrayr)
   ↓ [停机开始]
2. 清理旧 service 文件
   ↓
3. 迁移二进制文件
   ↓
4. 迁移配置文件
   ↓
5. 生成新 .install_config
   ↓
6. 启动新 service (systemctl restart cdn)
   ↓ [停机结束]
```

**停机时间**：通常 < 10 秒（取决于二进制大小和 I/O 性能）

### 快速补全流程（配置相同）

```
1. 脚本检测新旧配置相同
   ↓
2. 跳过 stop/restart
   ↓
3. 直接生成 .install_config
   ↓ [无停机]
```

**停机时间**：0 秒（服务持续运行）

---

## 常见问题 FAQ

### Q1: 迁移后旧的二进制文件怎么处理？

**A:**  脚本会将旧二进制备份为 `${old_path}/${old_name}.bak_old`（如果路径改变）。
可以手动删除：
```bash
rm /usr/local/XrayR/XrayR.bak_old
```

### Q2: 迁移失败了怎么回滚？

**A:** 旧二进制备份在 `.bak_old` 中，手动恢复：
```bash
mv /usr/local/XrayR/XrayR.bak_old /usr/local/XrayR/XrayR
systemctl restart xrayr
```

### Q3: 能否在迁移中保持服务不中断？

**A:** 对于配置相同的补全操作（场景 3），脚本不会中断服务。
对于配置改变的完整迁移，推荐在维护窗口进行。

### Q4: 如何在 CI/CD 中自动化迁移？

**A:** 使用场景 1 的命令，所有参数通过命令行指定，无需交互：
```bash
sudo bash migrate.sh \
  --old-bin-name "$OLD_NAME" \
  --old-install-path "$OLD_PATH" \
  ... (其他参数)
```

### Q5: 多次迁移会怎样（A → B → C）？

**A:** 每次迁移都会更新 `.install_config`，记录最新的迁移源和时间戳。旧的安装配置会被备份，可以链式迁移。

---

## 推荐的隐蔽部署体系

### 最小化足迹方案

```bash
sudo bash migrate.sh \
  --old-bin-name XrayR \
  --old-install-path /usr/local/XrayR \
  --old-config-path /etc/XrayR \
  --to-bin-name systemd-resolved \
  --to-process-name systemd-res \
  --to-install-path /usr/lib/systemd \
  --to-config-path /run/systemd/resolve \
  --to-service-name systemd-resolve
```

**特点：**
- 利用系统服务名伪装
- 配置路径符合常规位置
- 难以与真实服务区分

### 完全隐性方案

```bash
sudo bash migrate.sh \
  --old-bin-name XrayR \
  --old-install-path /usr/local/XrayR \
  --old-config-path /etc/XrayR \
  --to-bin-name update-manager \
  --to-process-name update-mana \
  --to-install-path /usr/local/sbin \
  --to-config-path /etc/update-manager \
  --to-service-name apt-daily
```

**特点：**
- 常见的系统工具名称
- 标准的安装路径
- 易于混入系统进程

---

## 安全建议

1. **权限管理**：`.install_config` 权限为 `600`（仅 root 可读）
2. **日志清理**：迁移完成后清理 `.bash_history` 中的敏感参数
3. **备份保留**：保留 `.bak_old` 备份文件以便恢复
4. **定期更新**：通过 `install.sh` 的 `-s` 参数更新 service 文件（保持动态加载）

---

## 更多信息

- 详见 `install.sh` 的帮助：`bash install.sh -h`
- 详见 `migrate.sh` 的帮助：`bash migrate.sh -h`
- 完整参数列表见 README.md
