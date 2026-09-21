<p align="center">
  <img src="assets/logo.svg" width="88" alt="IT之家 WinUI 客户端" />
</p>

<div align="center">

# IT之家 WinUI 客户端

一款基于 WinUI 3 的第三方 Windows 桌面客户端。<br/>
为「IT之家」提供符合 Windows 11 设计语言的阅读与社区体验。

<p align="center">
    <a title="下载最新版本" href="https://github.com/diave971/IThome-For-WinUI/releases/latest">下载应用</a>
    ·
    <a title="全部版本" href="https://github.com/diave971/IThome-For-WinUI/releases">全部版本</a>
    ·
    <a title="反馈问题" href="https://github.com/diave971/IThome-For-WinUI/issues/new/choose">反馈问题</a>
</p>

</div>

---

## 设计初衷

官方 UWP 客户端长久未维护，而日常又有着在桌面端浏览新闻资讯与社区讨论的习惯；网页端在 PC 宽屏下往往排版分散、多标签来回切换繁琐，且缺少 Windows 原生桌面的手感与质感。

本项目初衷便是打造一款**干净、流畅、深度契合 Windows 11 设计语言**的第三方桌面客户端，让看资讯、刷圈子与翻阅神评重回丝滑自然的桌面原生体验。

## 资讯阅读

首页聚合官方各频道资讯，支持频道切换、一键快速刷新与无限滚动加载。文章正文使用本地 WebView2 外壳渲染，深浅色各有一套排版，尽量还原原网页的图文与代码块样式。

![资讯流与文章阅读](assets/news-article.png)

正文里的图片可点击放大，支持滚轮缩放、双击切换与保存到本地，长文滚动时缩略图按视口懒加载。

## 评论区

文章评论区支持热门 / 最新排序、楼中楼展开，以及点赞与回复。圈子帖子下的评论共用同一套组件。

![评论](assets/comments.png)

## 圈子

帖子流支持「最新回复 / 最新主帖 / 最新评价」三个维度切换，右侧为帖子详情与评论。支持热门话题、话题详情、用户主页与发帖管理。

![圈子](assets/quan.png)

## 好物

商品流与热卖榜，支持分类筛选与爆料入口，商品详情保留原始促销信息与到手价说明。

![好物](assets/lapin.png)

## 登录与账号

使用 IT之家账号登录，会话与评论、圈子共用。账号中心汇总评论、帖子、收藏与足迹。

![登录](assets/login.png)

![账号中心](assets/account.png)

> [!NOTE]
> 登录凭据以 Windows 凭据库（PasswordVault）保存，不上传第三方服务器。足迹、收藏与设置以 JSON 存放在 `%LocalAppData%\ITHomeWinUI\`，应用未使用数据库。

## 外观与设置

提供浅色 / 深色主题，窗口背景支持 Mica 与 Acrylic 材质。设置页可调整文章字号、界面与正文字体、是否显示图片、阅读进度条、评论输入栏等阅读行为。

![设置](assets/settings.png)

## 三态自适应布局

窗口宽度变化时在三种布局之间自动切换，同一套页面结构适配不同屏幕尺寸——从超宽屏的三栏，到笔记本的中屏，再到窄窗口的单栏。

**Wide（宽屏，三栏）**

![Wide 布局](assets/layout-wide.png)

**Medium（中屏，两栏）**

![Medium 布局](assets/layout-medium.png)

**Narrow（窄屏，单栏）**

![Narrow 布局](assets/layout-narrow.png)

## 下载与安装

> [!IMPORTANT]
> 应用**未做商业代码签名**，首次运行可能出现 SmartScreen 提示，选择「更多信息」→「仍要运行」即可。

每个 Release 同时提供 `SHA256SUMS.txt` 用于校验完整性。

| 安装方式 | 文件 | 说明 |
| --- | --- | --- |
| 绿色版（推荐） | `*-portable.zip` | 解压后直接运行 `ITHomeWinUI.exe`，**无需安装任何依赖** |
| MSIX 安装版 | `*.msix` | 需先信任随附证书，再双击安装 |

### 绿色版

1. 下载 `ITHomeWinUI-<版本>-windows-<架构>-portable.zip`
2. 解压到任意目录（**请勿在压缩包内直接运行**）
3. 双击 `ITHomeWinUI.exe`

产物为自包含发布，已内置 .NET 与 Windows App SDK 运行时，卸载即删除目录。

### MSIX 安装版

1. 下载 `.msix` 与 `ITHomeWinUI-signing.cer`
2. 双击 `.cer` → 「安装证书」→ 存储位置选**本地计算机** → 放入**受信任的根证书颁发机构**
3. 双击 `.msix` 完成安装

> [!WARNING]
> 跳过第 2 步会导致安装因证书链错误失败。若不便修改系统信任设置，请改用绿色版。

## 环境要求

| 项 | 要求 |
| --- | --- |
| 操作系统 | Windows 10 版本 1809（内部版本 17763）或更高 |
| 架构 | x64 / ARM64 |
| 运行时 | 无需额外安装（自包含发布） |
| WebView2 | Windows 10/11 通常已内置；若文章页空白请[安装 WebView2 运行时](https://developer.microsoft.com/microsoft-edge/webview2/) |

## 常见问题

<details>
<summary>文章打开后内容空白，或图片不显示</summary>

文章正文依赖 WebView2 运行时。Windows 11 与较新的 Windows 10 已内置；精简版系统请安装 [WebView2 运行时](https://developer.microsoft.com/microsoft-edge/webview2/) 后重启应用。
</details>

<details>
<summary>怎么彻底卸载、我的数据在哪</summary>

绿色版直接删除解压目录；MSIX 在「设置 → 应用」中卸载。
本地数据（足迹、收藏、设置与缓存）位于 `%LocalAppData%\ITHomeWinUI\`，如需彻底清理请手动删除该目录；若曾登录账号，凭据保存在系统的 Windows 凭据管理器中，可在应用内点击注销或在系统凭据管理器中清除。
</details>

<details>
<summary>为什么应用没有代码签名</summary>

本项目为个人维护的第三方客户端，未购买商业代码签名证书。安装包由 CI 使用自签证书签名，可自行核对 Release 中的 `SHA256SUMS.txt` 确认文件未被篡改。
</details>

## 关于源码

本项目为非官方第三方客户端，暂未获得 IT之家的正式授权。为防范合规风险并避免相关通信接口被恶意滥用，项目源代码暂不公开发布，本仓库仅用于分发构建产物与跟踪用户 Issue 反馈。感谢理解与支持。

## 反馈

- **程序缺陷、崩溃、显示异常**：[Bug 报告](https://github.com/diave971/IThome-For-WinUI/issues/new/choose)
- **功能想法与改进建议**：[功能建议](https://github.com/diave971/IThome-For-WinUI/issues/new/choose)
- **安全漏洞**：请走 [私密报告通道](https://github.com/diave971/IThome-For-WinUI/security/advisories/new)，勿公开提交（见 [SECURITY.md](SECURITY.md)）

提交前请先搜索既有 issue，避免重复；附上版本号与复现步骤会显著加快定位。

## 免责声明

1. **主体关系**：本项目为**非官方**第三方客户端，与 IT之家（青岛软媒网络科技有限公司）无任何隶属、关联、授权或许可关系。「IT之家」名称、商标、徽标以及应用内展示的文章、评论、圈子等内容的知识产权均归其原始权利人所有。
2. **数据与网络**：本项目所有网络通信均基于公开可达的网络协议进行，未对服务提供方的后端核心系统或非公开数据库进行未授权渗透与侵入；所展示的所有资讯、帖子及评论内容均为平台公开发布的数据，客户端本质仅作为面向 Windows 桌面的**本地数据显示与排版渲染工具**。
3. **用途限制**：本项目仅供个人技术交流、学习研究与日常阅读使用，**严禁将本客户端及其任何衍生品用于商业营利、流量变现或恶意抓取**。使用者因个人行为产生的一切风险与法律后果均由使用者自行承担。
4. **权利人通道**：若相关权利人认为本项目的某些呈现方式或功能侵犯了其合法权益，请通过反馈渠道（Issue / 邮件）联系维护者，维护者核实后将在第一时间积极配合修改或下线相应功能。

## 软件许可与使用说明

Copyright © 2026 [diave971](https://github.com/diave971) / ITHome Community. All rights reserved.

- **个人免费使用**：本客户端构建产物（安装包与便携版）供个人免费下载用于学习、交流与日常阅读，**禁止任何形式的商业转售、二次打包牟利或植入恶意代码**。
- **第三方开源组件**：本程序引用的第三方开源库（包括 Windows App SDK、CommunityToolkit、FluentIcons、HtmlAgilityPack 等）其知识产权均归原作者所有，分别遵循其各自的开源许可证。
