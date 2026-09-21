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

## 它适合谁

- 习惯在 Windows 桌面上读 IT之家，希望有一个**贴合系统风格**而不是网页套壳的客户端
- 需要**三栏大屏阅读**，一边看资讯流一边读正文，而不是在浏览器标签之间来回切
- 在意**本地足迹与收藏**，希望阅读记录留在自己机器上，而不是依赖云端账号

## 资讯阅读

首页聚合官方频道，支持分类切换、下拉刷新与滚动加载，置顶条目会带红标跟随信息流。文章正文使用本地 WebView2 外壳渲染，深浅色各有一套排版，尽量还原原网页的图文与代码块样式。

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
本地数据（足迹、收藏、设置、登录凭据）位于 `%LocalAppData%\ITHomeWinUI\`，如需彻底清理请手动删除该目录。
</details>

<details>
<summary>为什么应用没有代码签名</summary>

本项目为个人维护的第三方客户端，未购买商业代码签名证书。安装包由 CI 使用自签证书签名，可自行核对 Release 中的 `SHA256SUMS.txt` 确认文件未被篡改。
</details>

## 关于源码

本仓库是**发布与反馈仓库**，用于发布安装包与收集问题，**不包含应用程序源代码**，也不接受代码贡献。

核心源码在私有仓库中维护，本仓库的 GitHub Actions 工作流在发布时从私有仓库只读检出源码完成构建，产物直接附加到 Release。这样可以在源码不公开的前提下，保证发布产物可复现、反馈入口统一。

## 反馈

- **程序缺陷、崩溃、显示异常**：[Bug 报告](https://github.com/diave971/IThome-For-WinUI/issues/new/choose)
- **功能想法与改进建议**：[功能建议](https://github.com/diave971/IThome-For-WinUI/issues/new/choose)
- **安全漏洞**：请走 [私密报告通道](https://github.com/diave971/IThome-For-WinUI/security/advisories/new)，勿公开提交（见 [SECURITY.md](SECURITY.md)）

提交前请先搜索既有 issue，避免重复；附上版本号与复现步骤会显著加快定位。

## 免责声明

本项目为**非官方**第三方客户端，与 IT之家（青岛海尔软件有限公司）无任何关联、未获其授权或认可。「IT之家」及相关内容的商标与版权归其权利人所有。

应用内展示的所有内容均来自 IT之家公开接口与网页，仅供个人学习与技术研究使用，请勿用于任何商业用途。使用者需自行承担因使用本软件产生的一切风险与责任。

## 许可证

Copyright © 2026 [diave971](https://github.com/diave971). All rights reserved.

本仓库不包含源代码，仅发布构建产物与文档。
