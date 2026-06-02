# UUP → Tiny11 Builder

整合 [UUPDumpOnGitHub](https://github.com/Enderxity/UUPDumpOnGitHub) 和 [tiny11-automated](https://github.com/kelexine/tiny11-automated) 两个项目，一键从 UUPDump 构建精简版 Windows 11 ISO。

## 工作流程

```
① 本地用 UUPDump 生成 zip → 上传到 Filebin
② GitHub Actions 下载 UUPDump zip
③ 构建完整 Windows ISO
④ 运行 tiny11 精简脚本（Standard / Core / Nano 可选）
⑤ 生成最终 ISO → 上传到 Artifacts
```

## 系统特性

- **Administrator 账号已启用**，密码：`123456`
- **OOBE 完全跳过**——安装后直接进入桌面
- **系统需求绕过**——TPM、CPU、RAM、SecureBoot 检查全部跳过
- 时区预设为 **中国标准时间 (UTC+8)**

## 使用步骤

### 第一步：Fork 本仓库

点击 GitHub 页面右上角的 **Fork** 按钮，把本仓库复制到你的账号下。

### 第二步：在 UUPDump 选择 SKU 版本（重要！）

> ⚠️ **这一步是关键，Index 的设置取决于你选择了几个 SKU（版本）。**

在 [UUPDump](https://uupdump.net/) 选择好语言和版本后，进入 **选择 SKU / Select SKU** 页面。
此处**强烈建议只勾选 1 个版本**（多选会导致 ISO 内有多个 Index，增大体积）。

**推荐选项（单选 1 个即可）：**

| 版本（显示名称） | UUPDump 中的名称 | 用途建议 |
|---|---|---|
| ✅ **Windows 11 专业版** | Professional | 适合大多数场景，推荐 |
| ⬜ Windows 11 家庭中文版 | CoreCountrySpecific | 预装在中文品牌机 |
| ⬜ Windows 11 家庭版 | Core | 基础家庭用户 |
| ⬜ Windows 11 协同版 | ProfessionalWorkstation | 高端工作站 |

> 💡 **只勾选 1 个版本** → 生成的 ISO 中只有一个 Index=1
> 此时工作流的 `image_index` 参数始终填 **`1`** 即可。

如果选择了多个版本，ISO 中的 Index 编号规则如下（以英文版为例，中文版名类似）：

| Index | 版本 |
|-------|------|
| 1 | Windows 11 Home / Windows 11 家庭版 |
| 2 | Windows 11 Home Single Language / Windows 11 家庭中文版 |
| 3 | Windows 11 Education / Windows 11 教育版 |
| 4 | Windows 11 Pro / Windows 11 专业版 |
| 5 | Windows 11 Pro Education / Windows 11 专业教育版 |
| 6 | Windows 11 Pro for Workstations / Windows 11 协同版 |
| 7 | Windows 11 Pro N / Windows 11 专业版 N |

选择完版本后，在 **Conversion options** 页面：
- **Download and convert to ISO** — 选择此选项
- **Include updates** — 推荐开启
- **.NET Framework 3.5** — 见下方 `.NET 3.5` 说明

然后下载生成的 ZIP 文件。

### 第三步：上传到 Filebin

1. 打开 [Filebin](https://filebin.net/)
2. 把刚才下载的 UUPDump ZIP 文件拖进去
3. 上传完成后，浏览器地址栏会显示类似 `https://filebin.net/0uv3y9tjqm0hjb51` 的链接
4. 记下最后这段 **code**（例如 `0uv3y9tjqm0hjb51`）

### 第四步：运行工作流

1. 在你自己 Fork 的仓库中，点击 **Actions** 标签
2. 在左侧选择 **UUP → Tiny11 Build**
3. 点击 **Run workflow** 按钮
4. 填写参数：

| 参数 | 说明 | 示例 |
|---|---|---|
| `filebin_code` | Filebin 的 code | `0uv3y9tjqm0hjb51` |
| `tiny11_variant` | 精简模式 | `standard` / `core` / `nano` |
| `image_index` | **单版本 UUPDump 填 1** | `1`（默认） |
| `enable_dotnet35` | 启用 .NET 3.5（仅 Core 变体） | 默认 `false` |
| `skip_cleanup` | 保留临时文件（调试用） | 默认 `false` |

### 第五步：下载结果

工作流完成后，在 **Summary** 页面底部的 **Artifacts** 区域找到 ISO 文件并下载。

## 精简变体对比

| 变体 | 脚本 | 体积 | 特性 |
|---|---|---|---|
| **Standard** | `tiny11maker-headless.ps1` | ~3-4 GB | 保留 Windows Update，适合日常使用 |
| **Core** | `tiny11coremaker-headless.ps1` | ~2 GB | WinSxS 极致精简，不可更新，适合 VM/测试 |
| **Nano** | `nano11builder-headless.ps1` | ~1.5 GB | 最激进精简（驱动/字体/服务），仅限 VM |

## .NET Framework 3.5 说明

**UUPDump 中的 ".NET Framework 3.5" 选项** 和 **tiny11 `enable_dotnet35` 参数** 之间的关系：

| 方式 | 作用阶段 | 原理 |
|---|---|---|
| UUPDump 选项（在生成 ZIP 时勾选） | ISO 构建前 | 将 .NET 3.5 源文件（`sxs` 文件夹）打包到生成的 ISO 中 |
| tiny11 `enable_dotnet35=true` | 精简阶段 | 在精简过程中通过 DISM 安装 .NET 3.5 |

**两者不会冲突**，但最佳做法是：

1. **在 UUPDump 中勾选 ".NET 3.5"** — 这样 ISO 中包含 .NET 3.5 源文件，tiny11 脚本才能安装它（需要 `sxs` 源）
2. **在工作流中设置 `enable_dotnet35=true`** — 让 tiny11 在精简时实际安装 .NET 3.5

> 如果 UUPDump 中没有勾选 .NET 3.5，但工作流中设置了 `enable_dotnet35=true`，tiny11 脚本会尝试从 ISO 的 `sources/sxs` 目录安装。如果源文件缺失，安装会跳过并记录一个警告，不影响系统使用。

## 自动检测说明

脚本现在包含**自动 Index 检测**功能，处理以下情况：

1. **中文版名**：`Windows 11 专业版`、`Windows 11 家庭版` 等中文版名会被正确识别
2. **Index 不匹配**：如果你填了 Index 6，但 ISO 中只有 Index 1（专业版），脚本会自动修正为 Index 1
3. **完全未知的版名**：兜底使用 Index 1（这也是为什么建议单版本 UUPDump 始终填 1）

## 文件结构

```
.
├── .github/workflows/build.yml        # GitHub Actions 工作流
├── autounattend.xml                    # 自动应答文件（Admin + OOBE）
├── upload.cmd                          # GoFile 上传脚本（可选）
├── scripts/
│   ├── tiny11maker-headless.ps1        # Standard 精简脚本
│   ├── tiny11coremaker-headless.ps1    # Core 精简脚本
│   ├── nano11builder-headless.ps1      # Nano 精简脚本
│   ├── tiny11maker-BASE.ps1            # Standard 基础脚本（参考）
│   ├── tiny11Coremaker-BASE.ps1        # Core 基础脚本（参考）
│   ├── nano11builder-BASE.ps1          # Nano 基础脚本（参考）
│   ├── discord_notify.py               # Discord 通知脚本（预留）
│   └── microsoft_direct_downloader.py  # 微软直链下载脚本（预留）
└── README.md
```

## 注意事项

1. **管理员密码** `123456` — 请在生产环境前自行修改（修改 `autounattend.xml` 中的密码）
2. **Core 和 Nano** 变体移除了 Windows Update 功能，不可安装后续更新
3. 构建耗时约 **60–120 分钟**（取决于 UUPDump 下载速度和 tiny11 精简复杂度）
4. 需要 GitHub Actions 的 Windows runner，免费额度足够使用
5. 所有 PS1 脚本来自 [tiny11-automated](https://github.com/kelexine/tiny11-automated)，仅修改了 `Resolve-ImageIndex` 函数以支持中英文版名

## Credits

- [Enderxity/UUPDumpOnGitHub](https://github.com/Enderxity/UUPDumpOnGitHub) — Actions 中从 UUPDump 构建 ISO
- [kelexine/tiny11-automated](https://github.com/kelexine/tiny11-automated) — 自动精简 Windows 11
- [ntdevlabs/tiny11builder](https://github.com/ntdevlabs/tiny11builder) — 原始 tiny11 构建脚本
