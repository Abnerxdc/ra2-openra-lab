# RA2 OpenRA Lab

基于 OpenRA/ra2 的红警2桌面客户端评估项目，优先评估本体、单人遭遇战和现代 Windows 支持。

项目全部内容及 Git 仓库位于 `ra2-openra-lab/` 子目录；父目录不作为项目仓库。

## 当前状态

- 已完成目录迁移，保留原有脚本及本地报告。
- 本地报告确认四个基础及扩展 MIX 文件存在，记录大小和 SHA-256；这不证明真实性、结构完整性或导入兼容性。未发现独立 theme.mix，不能据此判定缺少音乐。
- GitHub 仓库已存在且公开：<https://github.com/Abnerxdc/ra2-openra-lab>。
- 命令和文件操作恢复；沙箱内网络失败，沙箱外 GitHub 读取成功。
- 本机没有 .NET SDK；须先按上游配套版本准备。
- 尚未完成构建、规则检查、资源结构检查、无界面对局验证。

## 本机检查

```powershell
./scripts/Test-Environment.ps1
./scripts/Test-LocalResources.ps1 -ResourceDirectory '<游戏资源目录>'
```

资源报告仅保留在忽略的 `reports/`，资源和本机配置仅保留在忽略的 `local/` 或 `assets/local/`。`upstream/` 保存上游独立检出；`docs/` 保存评估记录，`scripts/` 保存验证工具。

禁止启动游戏、启动器、安装程序、图形测试或声音，禁止修改平台及游戏原文件。只执行编译、只读资源检查和经审查的无界面入口。图形、音效、操作及完整对局验证需以后另行授权。

当前仓库管理文档、脚本及后续自有资源；上游是否采用 fork 在结构审查后决定。保留上游许可证与署名，尚未选择项目整体许可证。不得上传原版资源、程序、凭据、本机路径或资源报告，即使仓库私有。

上游：<https://github.com/OpenRA/ra2>；引擎：<https://github.com/OpenRA/OpenRA>。必须固定模组及其指定引擎版本。
