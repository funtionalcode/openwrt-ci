# OpenWrt 云编译 - UFI103_CT

高通骁龙410 (MSM8916) 随身WiFi OpenWrt 固件自动编译。

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

## 使用方式

### 1. 手动触发编译

1. Push 到 GitHub
2. 进入 Actions → Build OpenWrt for UFI103_CT → Run workflow
3. 可选参数：
   - `source_repo`: OpenWrt 源码仓库
   - `source_branch`: 源码分支
   - `build_debug`: 调试模式（详细日志）

### 2. 自动触发

修改 `config/ufi103.seed` 后推送，自动触发编译。

### 3. 下载固件

编译完成后在 Actions 页面下载 Artifacts。

## 修改包列表

编辑 `config/ufi103.seed`，添加或删除 `CONFIG_PACKAGE_xxx=y` 行。

## 更换源码仓库

默认使用 hkfuertes/msm8916-openwrt，如需更换：

- 方式1：修改 workflow 的 `default` 参数
- 方式2：手动触发时填写 `source_repo` 和 `source_branch`

常见源码仓库：
| 仓库 | 说明 |
|------|------|
| https://github.com/hkfuertes/msm8916-openwrt | MSM8916 专用，推荐 |
| https://github.com/nikkit-team/immortalwrt | ImmortalWrt 分支 |
| https://github.com/openwrt/openwrt | 官方源码（可能缺少 UFI 设备支持）|

## 刷机

1. 备份原厂固件（9008模式全量备份）
2. 进入 Fastboot 模式
3. 刷入编译好的固件
4. 恢复基带文件到 `/lib/firmware/`

## 注意事项

- GitHub Actions 免费账户单次最长 6 小时
- 磁盘空间约 14GB，包不要选太多
- Nikki 和第三方 Feeds 仓库地址可能变化，需定期检查
- 首次编译约 2-4 小时，有缓存后约 30-60 分钟