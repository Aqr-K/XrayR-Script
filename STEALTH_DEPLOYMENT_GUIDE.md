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

---

## 链式迁移 (Chained Migration)

### 什么是链式迁移？

链式迁移是指在已迁移的基础上，再次迁移到新的参数。形成一条迁移链：
```
原始安装 (A) → 第1次迁移 (B) → 第2次迁移 (C) → 第3次迁移 (D) → ...
```

### 链式迁移的备份机制

每个迁移节点都会产生两层备份：

1. **上一个节点的二进制**：`${OLD_INSTALL_PATH}/${OLD_BIN_NAME}.bak_old`
2. **上一个节点的配置目录**：`${OLD_CONFIG_PATH}.backup_${timestamp}`
3. **新节点已有配置的冲突处理**：`${NEW_CONFIG_PATH}.backup_${timestamp}`

### 实际案例：三次链式迁移

#### 初始状态
```
/usr/local/XrayR/XrayR              ← 原始二进制
/etc/XrayR/                         ← 原始配置
  config.json
  subscription.txt
  ...
```

#### 第1次迁移（XrayR → cdn-service）
```bash
sudo bash migrate.sh \
  --old-bin-name XrayR --old-install-path /usr/local/XrayR --old-config-path /etc/XrayR \
  --to-bin-name cdn-service --to-install-path /opt/cdn --to-config-path /etc/cdn
```

**迁移后结果：**
```
/usr/local/XrayR/XrayR.bak_old              ← 备份的原始二进制
/etc/XrayR.backup_1234567890/               ← 备份的原始配置
  config.json
  subscription.txt
  ...

/opt/cdn/cdn-service                        ← 新二进制
/etc/cdn/                                   ← 新配置（从旧配置复制）
  config.json
  subscription.txt
  .install_config                           ← 记录第1次迁移信息
```

#### 第2次迁移（cdn-service → hidden-daemon）
```bash
sudo bash migrate.sh \
  --old-bin-name cdn-service --old-install-path /opt/cdn --old-config-path /etc/cdn \
  --to-bin-name hidden-daemon --to-install-path /usr/lib/hidden --to-config-path /etc/hidden
```

**迁移后结果：**
```
/usr/local/XrayR/XrayR.bak_old              ← 第1代备份二进制（保留）
/etc/XrayR.backup_1234567890/               ← 第1代备份配置（保留）

/opt/cdn/cdn-service.bak_old                ← 备份的第1代二进制
/etc/cdn.backup_1234567891/                 ← 备份的第1代配置
  config.json
  subscription.txt
  .install_config                           ← 仍保留第1次迁移信息

/usr/lib/hidden/hidden-daemon               ← 新二进制
/etc/hidden/                                ← 新配置（从第1代配置复制）
  config.json
  subscription.txt
  .install_config                           ← 记录第2次迁移信息
```

#### 第3次迁移（hidden-daemon → another-name）
```bash
sudo bash migrate.sh \
  --old-bin-name hidden-daemon --old-install-path /usr/lib/hidden --old-config-path /etc/hidden \
  --to-bin-name another-name --to-install-path /some/path --to-config-path /etc/another
```

**完整的迁移链结果：**
```
# 历代二进制备份
/usr/local/XrayR/XrayR.bak_old              ← 第0代 (原始)
/opt/cdn/cdn-service.bak_old                ← 第1代
/usr/lib/hidden/hidden-daemon.bak_old       ← 第2代

# 历代配置备份
/etc/XrayR.backup_1234567890/               ← 第0代配置
/etc/cdn.backup_1234567891/                 ← 第1代配置
/etc/hidden.backup_1234567892/              ← 第2代配置

# 当前部署
/some/path/another-name                     ← 最新二进制
/etc/another/                               ← 最新配置
  .install_config                           ← 记录第3次迁移信息
```

### 回溯恢复

若要回溯到某个历史版本：

```bash
# 回到第1代部署（cdn-service）
sudo systemctl stop another
cp -r /etc/cdn.backup_1234567891/* /etc/cdn/
sudo systemctl stop another  # 停止当前服务
cp /opt/cdn/cdn-service.bak_old /opt/cdn/cdn-service  # 若需恢复二进制
sudo systemctl restart cdn

# 回到第0代部署（原始 XrayR）
sudo systemctl stop cdn
cp -r /etc/XrayR.backup_1234567890/* /etc/XrayR/
cp /usr/local/XrayR/XrayR.bak_old /usr/local/XrayR/XrayR
sudo systemctl restart xrayr
```

### 链式迁移的使用场景

1. **灾难恢复**：快速回到任何历史版本部署
2. **A/B 测试**：在多个隐蔽配置间切换
3. **持续隐匿**：定期改变迁移参数以增加难度
4. **审计追踪**：`.install_config` 和备份目录提供完整操作历史

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

**A:** 每次迁移都会更新 `.install_config`，记录最新的迁移源和时间戳。

**备份机制：**
- **二进制备份**：路径改变时，旧二进制保留为 `${old_path}/${old_name}.bak_old`
- **配置备份**：路径改变时，旧配置完整保存为 `${old_path}.backup_${timestamp}`（支持链式回溯）
- **新位置冲突**：新配置路径已有文件时，自动备份为 `${new_path}.backup_${timestamp}`

**链式迁移例子：**
```bash
# 第1次迁移：XrayR → cdn-service
sudo bash migrate.sh --old-bin-name XrayR --old-install-path /usr/local/XrayR \
  --to-bin-name cdn-service --to-install-path /opt/cdn --to-config-path /etc/cdn

# 结果备份：
# /usr/local/XrayR/XrayR.bak_old           ← 第一代二进制
# /etc/XrayR.backup_1234567890             ← 第一代配置

# 第2次迁移：cdn-service → hidden-daemon
sudo bash migrate.sh --old-bin-name cdn-service --old-install-path /opt/cdn \
  --to-bin-name hidden-daemon --to-install-path /usr/lib/hidden --to-config-path /etc/hidden

# 结果备份：
# /opt/cdn/cdn-service.bak_old             ← 第二代二进制
# /etc/cdn.backup_1234567891               ← 第二代配置
# /etc/XrayR.backup_1234567890             ← 第一代配置（保留）

# 第3次迁移：hidden-daemon → ...（可继续链式迁移）
```

**回溯方法**：需要回到某个历史版本时，可恢复相应的 `.backup_*` 目录。

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
2. **备份清理**：定期清理 `.backup_*` 目录和 `.bak_old` 文件以减少足迹（保留最近的备份以备恢复）
3. **日志清理**：迁移完成后清理 `.bash_history` 中的敏感参数
4. **定期更新**：通过 `install.sh` 的参数更新 service 文件（保持动态加载）

### 备份清理示例

```bash
# 查看所有备份
find /etc -name ".backup_*" -o -name "*.bak_old" 2>/dev/null

# 删除旧备份（保留最近10天内的）
find /etc /usr/local /opt -name ".backup_*" -type d -mtime +10 -exec rm -rf {} \;
find /opt -name "*.bak_old" -type f -mtime +10 -delete

# 清理 bash 历史
history -c     # 清空当前会话历史
cat /dev/null > ~/.bash_history  # 清空历史文件
```

---

## 更多信息

- 详见 `install.sh` 的帮助：`bash install.sh -h`
- 详见 `migrate.sh` 的帮助：`bash migrate.sh -h`
- 完整参数列表见 README.md
