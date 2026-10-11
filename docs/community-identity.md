# Loftify Community Windows 身份与存储（Issue #3）

## 固定身份

| 项目 | 社区约定 |
| --- | --- |
| 显示名称、Windows ProductName / FileDescription | Loftify Community |
| Windows CompanyName | FlozeIII |
| 主程序 | LoftifyCommunity.exe |
| 发行身份 | io.github.flozeiii.loftify.community |
| Inno Setup AppId | DC4EB2B7-7325-40AC-A9E1-FA2F26F77F14 |
| 默认安装目录 | `%LOCALAPPDATA%\Programs\Loftify Community` |
| 安装模式 | 当前用户，无需管理员权限 |
| 安装注册项 | `HKCU\Software\FlozeIII\Loftify Community` |
| App Paths | `HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\LoftifyCommunity.exe` |
| 安装版协议 | `HKCU\Software\Classes\loftify-community` |

ZIP 启动不注册协议；安装器只注册社区协议。不会接管上游的 `lofter` 协议。安装器拒绝安装到存在 `Loftify.exe` 的目录，不使用上游的 AppId `BED24EC1-0C45-4AED-94C7-69F3A620CFCD`。

## 数据位置

| 数据 | 发布版实际目录 |
| --- | --- |
| 应用数据根目录 | `%APPDATA%\FlozeIII\Loftify Community` |
| Hive 设置、认证及下载记录 | 数据根目录下的 `settings.hive` |
| CookieJar | 数据根目录下的 `Cookies` |
| SQLite | 数据根目录下的 `Database\loftify.db` |
| 字体、日志、备份、截图 | 数据根目录下的 `Fonts`、`Logs`、`Backup`、`Screenshots` |
| 图片缓存及临时下载 | `%LOCALAPPDATA%\FlozeIII\Loftify Community\Cache` |
| Windows WebView2 的默认用户数据 | 社区主程序对应的 `LoftifyCommunity.exe.WebView2` 目录，与上游程序目录分开 |

Windows `path_provider_windows` 2.3.0 从运行程序资源中的 CompanyName 和 ProductName 建立应用支持与应用缓存目录。本次改动核对了该依赖源码：`getTemporaryPath` 原本返回公共系统临时目录，因此社区启动在打开存储之前配置独立临时目录；缓存组件、缓存大小统计、清理缓存及下载临时文件共同使用该目录。

ZIP 与安装版使用相同的社区数据身份。便携 ZIP 的含义是解压可运行，数据不存放在 ZIP 解压目录内。调试构建的 Hive 等支持目录由既有 FileUtil 追加 `-Debug`。

用户选择的下载目标保存在设置中；初始化、改名及安装/卸载不移动或删除已下载文件。卸载保留应用数据，并只清除本安装器拥有的程序文件、快捷方式和社区注册项。开机启动项只在命令指向本次卸载的程序时清除。

默认设置只填补不存在的键，初始化完成后才进入界面。不会把默认值写到已有明确选择上。社区启动不调用整体目录复制/删除的旧迁移辅助函数，不自动读取或导入旧认证状态；显式导入属于 Issue #5 / #6。

## 两类发行包

同一次 Windows 编译结果交给 `tools/windows_tools/package_windows.ps1`，依次产生社区 ZIP 和安装器。安装器编译失败即整个打包任务失败。两类产物均附 SHA256，包含一致的 `BUILD-PROVENANCE.json` 与主程序、SQLite、Flutter 和其他运行依赖。

主程序旁的 `DISTRIBUTION.json` 是发行形式约定，不从文件名或安装路径猜测：

```json
{
  "schemaVersion": 1,
  "applicationId": "io.github.flozeiii.loftify.community",
  "kind": "portable",
  "version": "2.5.3",
  "platform": "windows",
  "architecture": "x86_64",
  "sourceCommit": "<完整 Git SHA>"
}
```

安装器暂存目录的 `kind` 为 `installed`，其他字段与 ZIP 一致。缺失、不支持或不匹配的元数据应视为未知发行形式，后续更新逻辑不得回退上游或猜测安装器。Issue #9 将消费此约定。

本票保留现有版本号 2.5.3，用构建来源和独立发行身份区分本次验证产物；不发布 Release、不承诺新稳定版。公开社区测试版与版本过渡由 Issue #7 / #11 落实，许可材料由 Issue #10 在公开前核对。

## 验证记录

- 2026-10-11：Actions 在旧源码上复现 SQLite 路径断言失败（工作目录中的默认数据库位置）；修复后该项通过。
- 2026-10-11：Actions 在旧初始化逻辑上复现保存的偏好被覆盖；本次改为按键存在性填补默认值。
- 本地便携打包测试覆盖完整 ZIP、社区发行元数据、源码及校验、缺失 SQLite、已有 ZIP 冲突、同源安装暂存目录与发行形式区别。
- 2026-10-11：缓存测试在未隔离的路径实现上实际失败；修复后的 4 项存储测试以及完整测试通过。首次集成构建在安装器工具准备步骤停止：Chocolatey 没有版本 6.4.3。核对公开包目录后改为存在的 6.7.1，继续构建最终包。
- 两轴复查要求精确匹配启动程序路径，并兼容旧插件写入的无参数、未加引号完整路径。卸载器已修正，新启动项使用带引号路径；相似文件名或仅出现在参数中的路径不被当作本安装器所有。
- 最终包及 Windows 实机验收正在进行；本记录不把构建成功当作实机通过。
