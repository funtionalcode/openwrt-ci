# OpenWrt CI 项目规范

## Git 工作流规范

### 提交和 PR 流程

每次提交前必须遵循以下流程:

1. **创建分支**: 从 main 分支创建功能分支
   ```bash
   git checkout main
   git pull origin main
   git checkout -b <feature-branch>
   ```

2. **Rebase main**: 确保分支与 main 同步
   ```bash
   git rebase main
   ```

3. **提交变更**: 使用 conventional commits 格式
   ```bash
   git add <files>
   git commit -m "<type>: <description>"
   ```

4. **推送并创建 PR**: 推送分支后，通过以下链接创建 PR:
   ```
   https://github.com/<owner>/<repo>/compare/main...<branch-name>
   ```

5. **PR 描述模板**:
   ```markdown
   ## Summary
   <1-3 bullet points>

   ## Test plan
   <Checklist of verification steps>
   ```

## 项目结构

```
openwrt-ci/
├── .github/workflows/build.yml   # GitHub Actions 云编译工作流
├── config/ufi103.seed            # 编译配置（包列表）
├── .gitignore
└── AGENTS.md                     # 本文件
```

## 设备信息

| 项目 | 值 |
|------|-----|
| 型号 | UFI103_CT |
| SoC | 高通骁龙410 (MSM8916) |
| CPU | 4核 Cortex-A53 1.2GHz |
| 内存 | 512MB DDR3 |
| 存储 | 4GB eMMC |
| 编译架构 | aarch64_generic_musl |

## 编译源码

- **OpenWrt 官方源码**（自动获取最新 25.12.x）
- **MSM8916 补丁**：https://github.com/hkfuertes/msm8916-openwrt
- **第三方包**：
  - Nikki: https://github.com/nikkinikki-org/OpenWrt-nikki（feed 方式）
  - Argon 主题: https://github.com/jerrykuku/luci-theme-argon（git clone 到 package/）
  - FRP: https://github.com/kuoruan/luci-app-frpc + https://github.com/kuoruan/openwrt-frp（git clone 到 package/）

## 工作流

### 触发方式

1. **自动触发**：修改 `config/ufi103.seed` 后 PR 合并到 main 自动编译
2. **手动触发**：Actions 页面 Run workflow，可选参数：
   - `openwrt_version`: 留空自动获取最新 25.12.x
   - `device`: uz801 或 uf02
   - `build_debug`: 调试模式

### 创建 PR 链接

修改后推送分支，通过以下链接创建 PR：

```
https://github.com/funtionalcode/openwrt-ci/compare/main...<分支名>
```

当前待合并的 PR：

- https://github.com/funtionalcode/openwrt-ci/compare/main...fix/workflow-build

### 产出格式

编译完成后产物为 `OpenWrt_UFI103_CT_v25.12.x.zip`，包含：

| 文件 | 说明 |
|------|------|
| `gpt_both0.bin` | 分区表 |
| `boot.img` | 内核 + 设备树 |
| `rootfs.img` | 根文件系统 |
| `flash.bat` | Windows 刷机脚本 |
| `flash.sh` | Linux/Mac 刷机脚本 |
| `build_info.txt` | 构建信息 |

**注意**：`hyp.mbn`、`rpm.mbn`、`sbl1.mbn`、`tz.mbn`、`aboot.bin`、`fsc.bin`、`fsg.bin`、`modemst1.bin`、`modemst2.bin` 等基带文件不包含在编译产物中，需要从原厂备份提取。

## 包列表

修改 `config/ufi103.seed` 添加或删除包，主要包：

| 类别 | 包 |
|------|-----|
| 核心 | luci, luci-i18n-base-zh-cn, luci-theme-argon |
| WiFi | wpad-wolfssl, iw, iwinfo |
| 防火墙 | luci-app-firewall, iptables-mod-tproxy, iptables-mod-nat-extra |
| 4G基带 | kmod-usb-serial-option, luci-proto-qmi, uqmi |
| USB共享 | kmod-usb-net-rndis, kmod-usb-net-cdc-ether |
| 组网 | luci-app-frpc, wireguard-tools, luci-proto-wireguard |
| 代理 | luci-app-nikki (mihomo-meta) |
| 端口转发 | luci-app-socat |
| 监控 | luci-app-netdata, luci-app-nlbwmon |
| 工具 | luci-app-ttyd, luci-app-upnp, luci-app-ddns |

## 常见问题

### mkbootimg 找不到

MSM8916 设备编译需要 `mkbootimg`，已通过 `pip3 install mkbootimg` 安装。

### 第三方 Feed 索引缺失

Argon 主题和 FRP 不是 feed 格式，改为 `git clone` 到 `package/` 目录。Nikki 是标准 feed 格式，通过 `feeds.conf.default` 添加。

### mihomo 循环依赖

`mihomo-alpha` 和 `mihomo-meta` 互相依赖，seed 配置中显式选择 `mihomo-meta` 并排除 `mihomo-alpha`。

### WiFi 网速优化

刷机后执行：

```bash
uci set wireless.radio0.htmode='HT40'
uci set wireless.radio0.channel='6'
uci set wireless.radio0.country='US'
uci set wireless.radio0.txpower='20'
uci set wireless.@wifi-iface[0].encryption='psk2+ccmp'
uci commit wireless
wifi reload
```