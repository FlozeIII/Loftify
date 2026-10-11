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
| Windows WebView2 的默认用户数据 | 依赖源码推导为社区主程序对应的 `LoftifyCommunity.exe.WebView2` 目录；本次未实机触发 WebView2，尚未验收该位置 |

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
- 启动时只把与当前程序完整路径相符的无参数旧 Run 值规范为带引号命令，再查询插件状态；不会更改 Windows 的 StartupApproved 值，保留用户在系统中关闭启动项的选择。
- 源码 `424715fd854e8691426b42271e6750561597711e` 的 [Actions 38113952679](https://github.com/FlozeIII/Loftify/actions/runs/38113952679) 已通过静态分析、存储隔离、登录历史回归、打包契约、既有基线检查和完整测试集，Windows 主程序编译成功；Inno Setup 6.7.1 准备成功。两个审查方向的必修项均已修正并复查。
- 上述构建在安装器编译时发现 Pascal 代码段末尾使用了分号式注释，报 `'BEGIN' expected`；已改为 Pascal 接受的注释，并在两个工作流中将安装器编译检查提前到 Flutter 编译之前。
- 阶段源码 `67997dbb355a343115681792b09c7dc422723e3e` 的 [Actions 38114646534](https://github.com/FlozeIII/Loftify/actions/runs/38114646534) 全部成功：安装器脚本预检查、静态分析、4 项存储隔离测试、7 项登录交互测试、106 项基线测试、完整测试集、Windows 编译、真实 ZIP/安装器打包及上传。完整测试集通过仅依据该步骤成功状态，此处不推算测试总数。
- 该阶段包的官方 Actions 归档摘要、ZIP 与安装器 SHA256 均已在本机核对；Windows 产品资源和发行元数据符合约定。首次启动前社区数据目录不存在；首次启动后 Hive、Cookies、SQLite 和缓存位于社区路径，SQLite 文件为真实数据库。启动与正常退出后，上游身份数据根目录中 9 个文件的摘要均未变化。
- 实机发现首次登录面板关闭按钮无法退出：保存的根 context 位于 Navigator 外层。通过真实 MyApp + DialogBuilder 的回归测试复现 `Navigator operation requested with a context that does not include a Navigator`，与实机关闭按钮错误对应。根 context 现改为在使用时读取当前根导航器状态；原保存值仅作为导航器未挂载时的回退。两个审查方向均无必修项，继续构建并复验。
- 最终源码 `fa0effe253411852e1b91d8039e131d3ebab660b` 的 [Actions 38116883124](https://github.com/FlozeIII/Loftify/actions/runs/38116883124) 全部成功：安装器脚本预检查、针对性分析、4 项存储隔离测试、新增首次启动对话框回归、登录历史回归、7 项登录交互测试、打包契约、106 项基线测试、完整测试集、Windows 编译、安装器编译及产物上传。完整测试集不推算总数。

## 最终产物核对

两类包均来自上述最终源码，应用产品版本为 `2.5.3+2503`，包和安装器版本为 `2.5.3`。

| 产物 | SHA256 |
| --- | --- |
| `Loftify-Community-2.5.3-windows-x86_64.zip` | `0d05e2140e7734e0483fd856ec59b02a4f594e58fb12d1c9b271a11769f98bcf` |
| `Loftify-Community-2.5.3-windows-x86_64-setup.exe` | `40f7bed3f21eef1aad7bbd6984b75f6a84bfa0d8af79e1e9c04a4462d2565b41` |
| 官方 Actions 产物归档 | `8045aa3f7aba6acdedf967a7f16a310dd9bb1467aa4a3f1b1d43f9c273373db9` |

本机已核对校验和、DLL 与数据依赖、Windows 产品资源、`DISTRIBUTION.json` 及 `BUILD-PROVENANCE.json`。实际安装后，除发行形式元数据外的 125 个运行文件与最终 ZIP 全部摘要相同，含 `LoftifyCommunity.exe` 与 `data/app.so`。

## Windows 实机验收结果

2026-10-11，Windows 11 家庭中文版、x64、系统 build 26200。安装与配置恢复均经用户授权。

| 场景 | 实机结果 |
| --- | --- |
| 最终 ZIP，空数据首次启动 | 临时移出社区支持与缓存目录后启动；验证码面板正常显示，关闭后欢迎反馈提示可关闭，进入游客首页；本次新数据目录未生成 `error.log`。正常退出后保留新数据，并恢复此前社区数据。 |
| 已有社区设置重启 | 深色切换为浅色，正常退出与重新启动后浅色主题保留；关于页显示 Loftify Community。 |
| 数据实际位置 | Hive、Cookies、SQLite 与缓存位于社区目录；真实 `Database\loftify.db` 为 12288 字节，文件头为 `SQLite format 3\0`。社区单独启动与退出时，旧身份数据的 9 个文件摘要未变化。 |
| 与旧身份客户端并存 | 最终社区 ZIP 与旧身份 `Loftify.exe` 同时呈现两个独立窗口；社区浅色、旧客户端深色。旧客户端自己的启动会重写旧设置并显示上游更新提示，取消更新后退出；利用仓库外备份恢复旧数据与原启动值，9 个文件摘要全部恢复，旧 `lofter` 协议与验收前一致。 |
| 首次社区安装 | 阶段源码 `67997db` 的安装器成功安装至当前用户默认目录；跳过该阶段程序的安装后启动。桌面及开始菜单快捷方式、社区 App Paths、协议与卸载信息均使用独立身份。 |
| 覆盖升级 | 最终 `fa0effe` 安装器识别已有安装并覆盖至同一路径；发行元数据为 `installed`、来源为最终源码。浅色设置保留，游客登录面板打开和关闭均正常。 |
| 启动项 | 安装版临时启用开机启动后，Run 命令为带引号的完整社区程序路径；旧 Loftify Run 值保持原先不存在状态。 |
| 卸载 | 卸载成功；安装文件、两个快捷方式、社区产品注册项、App Paths、协议及卸载登记均清除，临时启用的社区 Run / StartupApproved 值清除。旧身份程序和协议保留。 |
| 卸载保留数据与文件 | 卸载前后社区支持目录的 10 个文件、缓存目录的 104 个文件及旧身份目录的 9 个文件摘要全部一致。下载目录中专门创建的无敏感信息验收文件原位置及摘要保持；验收后将该文件移到临时证据目录保存。 |
| 卸载后运行 ZIP | 最终 ZIP 可重新启动，浅色主题仍保留，正常退出；旧身份数据摘要仍无变化。社区 `error.log` 保持此前阶段错误的 3270 字节，最终包验收未追加错误。 |

### 验收边界

- 并存对象是采用上游身份的旧 fork 基线（源码 `c9e79380cad1b5d2e9d3c11e5ceb9f4c1702b8e2`），不是另行确认的官方上游安装；本机没有已注册的上游安装。结论覆盖该旧身份程序、数据与现存协议的隔离，不声称验证所有上游安装版本。
- 覆盖升级是 `67997db` 到 `fa0effe` 两份不同构建，显示版本均为 2.5.3；跨版本升级与正式发布由后续任务落实。
- 未登录真实账号、未提交验证码或请求短信。认证内容重启恢复及 WebView2 数据位置未在实机验证；本票已验证认证存储组件的独立目录，旧认证导入由后续任务实现。
- 下载保留使用验收文件和卸载前后目录摘要，未执行真实图片下载流程。安装器无数据删除段；此结论不代替后续下载功能验收。
- 私有数据备份、原始应用日志与本机快照保留在仓库外或未提交的 `.scratch/community-identity/evidence/`，不随代码发布。测试安装已卸载，测试进程均正常退出，社区已有设置和旧配置已恢复；未创建新 tag 或公开 Release。
