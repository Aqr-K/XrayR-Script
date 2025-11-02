# XrayR-Script

### 快速开始 (Quick Start)

复制以下命令，替换其中的**占位符**为您自己的信息，然后在您的服务器上执行。

```bash
curl -fsSL https://raw.githubusercontent.com/Aqr-K/XrayR-Script/main/install.sh | bash -s -- \
--mode install \
--xrayr-repo https://github.com/{OWNER}/{REPO} \
--xrayr-token {YOUR_PRIVATE_XRAYR_PLUS_TOKEN} \
--xrayr-version latest \
--config-repo https://github.com/{OWNER}/{REPO}/tree/main/config/ \
--config-token {YOUR_PRIVATE_CONFIG_REPO_TOKEN}
```

**推荐的更安全的使用方法是分步执行：**

1.  **下载脚本**
    ```bash
    curl -fL "https://raw.githubusercontent.com/Aqr-K/XrayR-Script/main/install.sh" -o install.sh
    ```

2.  **（可选但强烈建议）审查脚本内容**
    ```bash
    less install.sh
    ```

3.  **赋予权限并执行**
    ```bash
    chmod +x install.sh
    ./install.sh --mode install [其他参数...]
    ```

---

## 📄 许可证 (License)

本项目采用 [MIT License](https://opensource.org/licenses/MIT) 授权。
