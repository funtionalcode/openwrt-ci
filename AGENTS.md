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
├── devices/                      # 设备配置（每设备一个子目录）
│   ├── ufi103/
│   │   ├── seed                  # 编译配置（包列表）
│   │   ├── flash.bat             # Windows 刷机脚本
│   │   ├── flash.sh             # Linux/Mac 刷机脚本
│   │   └── files/                # 自定义文件（刷入固件）
│   │       └── etc/uci-defaults/ # 首次启动脚本
│   │       └── etc/hotplug.d/   # 热插拔脚本
│   ├── uz801/                    # (预留)
│   └── uf02/                     # (预留)
├── firmware/                     # 基带备份文件（gitignored）
├── .gitignore
└── AGENTS.md                     # 本文件
```

### 添加新设备

1. 创建 `devices/<device>/` 目录
2. 添加 `seed` 编译配置文件
3. 添加 `flash.bat` 和 `flash.sh` 刷机脚本
4. 可选：添加 `files/` 目录放置自定义文件
5. 在 `build.yml` 的 device options 中添加设备名

## 设备信息

| 项目 | UFI103_CT | UZ801 | UF02 |
|------|-----------|-------|------|
| SoC | 高通骁龙410 (MSM8916) | MSM8916 | MSM8916 |
| CPU | 4核 Cortex-A53 1.2GHz | 4核 Cortex-A53 | 4核 Cortex-A53 |
| 内存 | 512MB DDR3 | 512MB | 512MB |
| 存储 | 4GB eMMC | 4GB eMMC | 4GB eMMC |
| 编译架构 | aarch64_generic_musl | aarch64_generic_musl | aarch64_generic_musl |

## 编译源码

- **OpenWrt 官方源码**（自动获取最新 25.12.x）
- **MSM8916 补丁**：https://github.com/hkfuertes/msm8916-openwrt
- **第三方包**：
  - Nikki: https://github.com/nikkinikki-org/OpenWrt-nikki（feed 方式）
  - Argon 主题: https://github.com/jerrykuku/luci-theme-argon（git clone 到 package/）
  - FRP: https://github.com/kuoruan/luci-app-frpc + https://github.com/kuoruan/openwrt-frp（git clone 到 package/）

## 工作流

### 触发方式

1. **自动触发**：修改 `devices/**` 后 PR 合并到 main 自动编译
2. **手动触发**：Actions 页面 Run workflow，可选参数：
   - `openwrt_version`: 留空自动获取最新 25.12.x
   - `device`: ufi103 / uz801 / uf02
   - `build_debug`: 调试模式

### 创建 PR 链接

修改后推送分支，通过以下链接创建 PR：

```
https://github.com/funtionalcode/openwrt-ci/compare/main...<分支名>
```

### 产出格式

编译完成后产物为 `OpenWrt_<设备名>_v25.12.x.zip`，包含：

| 文件 | 说明 |
|------|------|
| `gpt_both0.bin` | 分区表 |
| `boot.img` | 内核 + 设备树 |
| `rootfs.img` | 根文件系统 |
| `flash.bat` | Windows 刷机脚本 |
| `flash.sh` | Linux/Mac 刷机脚本 |
| `fastboot.exe` | Windows fastboot 工具 |
| `build_info.txt` | 构建信息 |

**注意**：`hyp.mbn`、`rpm.mbn`、`sbl1.mbn`、`tz.mbn`、`aboot.mbn`、`fsc.bin`、`fsg.bin`、`modemst1.bin`、`modemst2.bin` 等基带文件不包含在编译产物中，需要从原厂备份提取，放入 `firmware/` 目录。

## 包列表

修改 `devices/<device>/seed` 添加或删除包，主要包：

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

## 刷机脚本说明

刷机脚本（flash.bat / flash.sh）流程：

1. **Phase 1**: 写入分区表 + 基带文件（如 firmware/ 目录存在则从中读取）
2. **Phase 2**: 清除 boot/rootfs 分区，重启设备
3. **Phase 3**: 等待设备重新进入 fastboot，写入 boot.img 和 rootfs.img

基带文件可选，脚本会自动跳过缺失的 .mbn 文件。

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
