# opencode-termux (OCT)

**中文** | **[English](README.md)**

OpenCode 的 Termux 打包与运行时工作流。

## 一键安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/androidly/opencode-termux/main/install.sh)
```

脚本会自动检测最新 release 版本并安装。

## 手动安装

根据你的包管理器选择对应路径。

### 路径 A：Termux 默认（apt/pkg）—— 推荐

```bash
apt install -y glibc-repo
apt update
apt install -y glibc openssl-glibc
dpkg -i /path/to/opencode_<version>_aarch64.deb
```

可选回退工具：

```bash
apt install -y glibc-runner
```

### 路径 B：pacman 环境

仅适用于已配置 pacman 为主要包管理器的 Termux。

```bash
pacman -Syu
pacman -S glibc openssl-glibc
pacman -U /path/to/opencode-<version>-aarch64.pkg.tar.xz
```

可选回退工具：

```bash
pacman -S glibc-runner
```

### 安装后验证

```bash
opencode --version
opencode --help
opencode web
```

## 仓库定位

本仓库属于 OML/OCT 轨道，聚焦于：

- 在真实 Termux 设备上进行可复现的 OpenCode 运行时打包
- 从一个暂存前缀同时输出 deb + pacman 包
- 为 Termux 运行时行为提供更安全的启动器默认值
- 插件生命周期支持（安装/更新/回滚/补丁）

## 当前状态（重要）

- 已验证运行时路径：OpenCode Runtime（Android/Bionic 封装）
- 最终包在 **本地 Termux** 上生成
- GitHub Actions 仅用于 **armv7 交叉预构建交接**（非主线/延期轨道）

### 完成情况

- ✅ 主线 Termux 打包流程（deb + pacman）已可用
- ✅ machine1(构建) → 本地中继 → machine2(测试) 生命周期已验证
- ✅ 插件/系统技能 hook 框架第二阶段已实现并测试（注册表 + 兼容性门控 + 黑名单）
- ✅ 只读诊断与矩阵模拟可用（`make selfcheck`、`make matrix`）
- 🚧 下一步：OML 父级编排目标与更丰富的插件策略控制

## 仓库结构

- `scripts/` — 本地构建 + 打包脚本
- `packaging/` — 包元数据/模板
- `tools/` — 辅助工具（`produce-local.sh`、`plugin-manager.sh`）
- `docs/` — 规范文档与运维手册

从这里开始：**`docs/README.md`**

## 构建模型（阶段 A/B/C）

### 阶段 A：CI armv7 预构建交接

工作流：`.github/workflows/prebuild-armv7.yml`

CI 生成交叉工具链证据与交接模板/产物。它 **不** 声称具备最终 Termux 运行时兼容性。

### 阶段 B：本地 Termux 最终构建/打包

使用真实 Termux 环境进行最终运行时封装与包生成。

典型流程：

```bash
./tools/produce-local.sh <version>
./scripts/build.sh
./scripts/package/package_deb.sh
./scripts/package/package_pacman.sh
```

### 阶段 C：插件生命周期

使用包管理器驱动的插件策略 + 本地可恢复性工具。

详见：
- `docs/plugin-packaging-design.md`
- `docs/plugin-management.md`

## 快速构建命令

```bash
make all VER=1.15.5 PKG=both          # 单版本，输出 deb + pacman
make all VER=latest PKG=pacman         # 最新版本，仅 pacman
make batch VERS='1.15.[1-5]' PKG=deb  # 批量版本
```

### 版本解析规则

`tools/produce-local.sh` 版本优先级：
1. 第一个位置参数（显式版本号）
2. npm 上 `opencode-linux-arm64` 的最新版本（未指定版本时）
3. 若 npm 无对应版本，回退下载 GitHub Release 二进制

### 输出策略

- 默认输出根目录：项目内 `packing/`
- 设置 `ODIR` 则输出到该目录
- `MIX=1`：所有产物平铺到同一目录

## 已验证的启动器安全措施

- 退出时 TTY 清理
- 过期锁文件清理
- 损坏插件缓存清理
- 默认 `OPENCODE_DISABLE_DEFAULT_PLUGINS=1`
- statx seccomp shim（`libstatx-shim.so`）：拦截 Android seccomp 阻止的 `statx()` 系统调用，返回 `-ENOSYS`，使 glibc 回退到 `stat`/`fstatat`（Android seccomp 阻止 `statx` → `SIGSYS` → `SIGSEGV`）。可通过 `OPENCODE_DISABLE_STATX_SHIM=1` 禁用。

## 本仓库不做的事

- 不使用 musl 作为 Termux 最终运行时路径
- 不使用 proot 作为官方构建路径
- 不将 CI 产物视为最终 Termux 发布二进制
- 默认包硬依赖为 `glibc`；`glibc-runner` 为可选回退工具

## 生命周期模拟与自检

```bash
# 升级/降级模拟
TARGET_HOST=192.168.1.22 TARGET_USER=u0_a258 \
  make matrix VERS='<旧版本> <新版本>' ODIR=~/oct-out

# 只读自检（不修改系统）
make selfcheck
```

## 快速链接

- Glibc 依赖精简报告：`docs/glibc-min-deps-test-report.md`
- 升级/降级模拟工具：`tools/upgrade-matrix.sh`
- 只读插件/环境自检：`tools/plugin-selfcheck.sh`
- 外部插件构建项目：<https://github.com/Hope2333/opencode-plugins-termux>
- 系统技能清单（包模式）：`packaging/manifests/system-skills/`
- Hook 运行器（包模式）：`scripts/hooks/run-system-skills.sh`
- 系统技能架构：`docs/system-skills-hook-architecture.md`
- 运行时构建详情：`docs/13-opencode-runtime-build.md`
- 打包文档：`docs/20-packaging-deb.md`、`docs/21-packaging-pkg-tar-xz.md`
- 执行清单：`docs/execution-checklist.md`

## 许可证 / 上游

- 上游 OpenCode：<https://github.com/anomalyco/opencode>
- 本打包工作流仓库遵循上游许可证约束分发产物。