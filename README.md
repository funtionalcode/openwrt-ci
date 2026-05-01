# OpenWrt 多设备云编译

高通骁龙410 (MSM8916) 随身WiFi OpenWrt 固件自动编译，支持多设备。

## 支持设备

| 设备 | 目录 | 状态 |
|------|------|------|
| UFI103_CT | `devices/ufi103/` | ✅ 可用 |
| UZ801 | `devices/uz801/` | 预留 |
| UF02 | `devices/uf02/` | 预留 |

## 项目结构

```
devices/<device>/
├── seed          # 编译配置（包列表）
├── flash.bat     # Windows 刷机脚本
├── flash.sh     # Linux/Mac 刷机脚本
└── files/        # 自定义文件（刷入固件）
```

## 构建流程

1. 从官方 OpenWrt 克隆源码（自动获取最新 25.12.x）
2. 从 hkfuertes/msm8916-openwrt 注入 MSM8916 设备支持
3. 添加第三方 Feeds（Nikki、Argon、FRP 等）
4. 根据 `devices/<device>/seed` 配置编译固件

## 触发方式

### 手动触发

Actions → Build OpenWrt → Run workflow

可选参数：
- `openwrt_version`: OpenWrt 版本标签（留空自动获取最新 25.12.x）
- `device`: 目标设备（ufi103 / uz801 / uf02）
- `build_debug`: 调试模式（详细日志）

### 自动触发

修改 `devices/**` 后，创建 PR 合并到 main 分支自动触发。

## 修改包列表

编辑 `devices/<device>/seed`，添加或删除 `CONFIG_PACKAGE_xxx=y` 行。

## 添加新设备

1. 创建 `devices/<device>/` 目录
2. 添加 `seed` 编译配置
3. 添加 `flash.bat` 和 `flash.sh`
4. 在 `build.yml` 的 device options 中添加设备名

## 下载固件

编译完成后在 Actions 页面下载 Artifacts。

## 刷机

1. 备份原厂固件（9008模式全量备份）
2. 进入 fastboot 模式（按住 reset 插入USB，或 `adb reboot bootloader`）
3. 将基带文件放入 `firmware/` 目录（可选，脚本自动跳过缺失文件）
4. 运行 `flash.bat`（Windows）或 `flash.sh`（Linux/Mac）

## 注意事项

- GitHub Actions 免费账户单次最长 6 小时
- Nikki 和第三方 Feeds 仓库地址可能变化，需定期检查
- 首次编译约 2-4 小时，有缓存后约 30-60 分钟
