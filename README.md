# OpenWrt 云编译 - UFI103_CT

高通骁龙410 (MSM8916) 随身WiFi OpenWrt 固件自动编译。

## 构建流程

1. 从官方 OpenWrt 克隆源码（自动获取最新 25.12.x）
2. 从 hkfuertes/msm8916-openwrt 注入 MSM8916 设备支持
3. 添加第三方 Feeds（Nikki、Argon、FRP 等）
4. 应用 ufi103.seed 配置编译固件

## 功能清单

| 类别 | 插件 |
|------|------|
| WiFi | wpad-wolfssl (STA+AP) |
| 4G基带 | QMI/3G拨号, 高通串口驱动 |
| USB共享 | RNDIS/CDC-ECM |
| 组网 | FRP客户端 + WireGuard |
| 代理 | Nikki (Mihomo/Clash Meta) |
| 端口转发 | Socat |
| 监控 | Netdata, NLBWmon |
| 工具 | ttyd, UPnP, DDNS |

## 触发方式

### 手动触发

Actions → Build OpenWrt for UFI103_CT → Run workflow

可选参数：
- `openwrt_version`: OpenWrt 版本标签（留空自动获取最新 25.12.x）
- `device`: 目标设备（uz801 / uf02）
- `build_debug`: 调试模式（详细日志）

### 自动触发

修改 `config/ufi103.seed` 后，创建 PR 合并到 main 分支自动触发。

## 修改包列表

编辑 `config/ufi103.seed`，添加或删除 `CONFIG_PACKAGE_xxx=y` 行。

## 下载固件

编译完成后在 Actions 页面下载 Artifacts。

## 刷机

1. 备份原厂固件（9008模式全量备份）
2. 进入 EDL 模式（按住 reset 插入USB，或 `adb reboot edl`）
3. 使用 `edl` 工具刷入固件
4. 恢复基带文件到 `/lib/firmware/`

## 注意事项

- GitHub Actions 免费账户单次最长 6 小时
- Nikki 和第三方 Feeds 仓库地址可能变化，需定期检查
- 首次编译约 2-4 小时，有缓存后约 30-60 分钟