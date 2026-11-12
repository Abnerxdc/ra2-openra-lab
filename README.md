# RA2 OpenRA Lab

基于 OpenRA/ra2 的红警2桌面客户端评估项目，优先评估本体、单人遭遇战和现代 Windows 支持。

项目全部内容及 Git 仓库位于 `ra2-openra-lab/` 子目录；父目录不作为项目仓库。

## 当前状态

- 已完成目录迁移，保留原有脚本及本地报告。
- 本地报告确认四个基础及扩展 MIX 文件存在，记录大小和 SHA-256；这不证明真实性、结构完整性或导入兼容性。未发现独立 theme.mix，不能据此判定缺少音乐。
- GitHub 仓库已存在且公开：<https://github.com/Abnerxdc/ra2-openra-lab>。
- 命令和文件操作恢复；沙箱内网络失败，沙箱外 GitHub 读取成功。
- 项目内已准备 .NET SDK 6.0.428，不要求全局安装 SDK。
- 配套引擎和模组 Release 编译及无界面 YAML 检查通过；本体资源已隔离复制，两个本体 MIX 及 20 个已知嵌套 MIX 索引检查通过。详见 [资源接入记录](docs/local-content.md)。尚未验证完整资源解码或完整对局。

## 原创玩法方向

已新增独立的“风暴断线 / Stormline”双阵营设计，保留 RA2 复刻基线。见 [玩法设计](design/stormline/gameplay.md)、[资源规范](design/stormline/assets.md) 和 [首批接入原型](stormline/prototype/README.md)。原型包含两辆主战车辆的原创静态 PNG、规则与武器，以及隔离暂存和无界面验证入口；尚无完整方向动画、可玩遭遇战或安装包。

## Windows 安装包进度

已实现 Windows 原生打包入口、用户级安装/卸载脚本、独立资源复制入口和运行时随包方案。安装包不携带原版 MIX；首次由用户选择本机资源。构建前使用包内运行时检查依赖、规则、地形/精灵、模型与声明音频，并扫描开发机路径。详见 [交付与验收记录](docs/windows-delivery.md)。当前属于待实际运行验收的本体预览构建；背景音乐供应、完整对局、Windows 实机与安装卸载尚未验收，不能视为最终交付。

## 本机检查

```powershell
./scripts/Test-Environment.ps1
./scripts/Test-LocalResources.ps1 -ResourceDirectory '<游戏资源目录>'
```

资源报告仅保留在忽略的 `reports/`，资源和本机配置仅保留在忽略的 `local/` 或 `assets/local/`。`upstream/` 保存上游独立检出；`docs/` 保存评估记录，`scripts/` 保存验证工具。

禁止启动游戏、启动器、安装程序、图形测试或声音，禁止修改平台及游戏原文件。只执行编译、只读资源检查和经审查的无界面入口。图形、音效、操作及完整对局验证需以后另行授权。

当前仓库管理文档、脚本及后续自有资源；上游是否采用 fork 在结构审查后决定。保留上游许可证与署名，尚未选择项目整体许可证。不得上传原版资源、程序、凭据、本机路径或资源报告，即使仓库私有。

上游：<https://github.com/OpenRA/ra2>；引擎：<https://github.com/OpenRA/OpenRA>。必须固定模组及其指定引擎版本。
