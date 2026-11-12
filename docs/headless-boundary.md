# 配套引擎的无界面边界

这是固定源码的入口审查记录，不是已执行完整对局的报告。

已审查并实际执行的入口：Utility 的 `--check-yaml` 与 `--check-missing-sprites`；项目的 MIX 索引、PNG、VXL/HVA、PCM 与字体文件头检查器；使用合成数据的资源复制测试。这些入口不创建游戏 World、渲染器或音频输出设备。

`OpenRA.Server/Program.cs` 的专用服务器入口初始化 NAT、载入地图缓存并监听 IPv4/IPv6 套接字，随后进入服务循环。`OpenRA.Game/Server/Server.cs` 的 StartGame 分发启动指令。仅启动它不能证明两个 AI 在服务器内完成采矿、建造、战斗与胜负，也不能作为单人完整对局验收。此项目没有执行该服务器入口，没有把网络监听成功记作玩法通过。

直接创建客户端 World 也不是当前可用的无界面对局替代：`OpenRA.Game/World.cs` 的构造访问 Game.Sound，PrepareMap 路径初始化加载器和模型；`OpenRA.Mods.Cnc/Graphics/VoxelModelSequenceLoader.cs` 的缓存完成调用 VoxelLoader.RefreshBuffer，后者在 `OpenRA.Mods.Cnc/Graphics/VoxelLoader.cs` 调用 Game.Renderer.CreateVertexBuffer。引擎虽然有 DummySoundEngine，但这不能消除模型加载的渲染器依赖。

因此没有把静音、隐藏窗口、未显示画面的客户端或专用服务器等同于可审查的纯逻辑完整对局。开发真正无界面的客户端仿真需要独立的渲染/模型/声音替身与对局控制入口，并有确定性及 AI 行为测试；当前尚未实现。也不能用替身测试替代真实画面、输入、音效、Windows 兼容性与完整流程验收。

下一项运行验收必须遵守用户关于桌面和声音的明确授权。源码入口审查与解码检查可以继续执行，但完整实机交付在该授权前仍未完成。
