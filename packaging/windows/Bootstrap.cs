using System;
using System.Diagnostics;
using System.IO;
using System.Security.Cryptography;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

// The installer never calls this program. Only the user's shortcut launches it.
internal static class ResourceStore
{
    internal static readonly string[] Required = { "ra2.mix", "language.mix" };

    internal static bool Ready(string support)
    {
        string content = Path.Combine(support, "Content", "ra2");
        foreach (string name in Required)
            if (!File.Exists(Path.Combine(content, name)) || new FileInfo(Path.Combine(content, name)).Length < 1024)
                return false;
        return File.Exists(Path.Combine(content, "import-complete.txt"));
    }

    internal static string Hash(string path)
    {
        using (var input = File.OpenRead(path))
        using (var sha = SHA256.Create())
            return BitConverter.ToString(sha.ComputeHash(input)).Replace("-", "");
    }

    internal static void Import(string source, string support)
    {
        foreach (string name in Required)
            if (!File.Exists(Path.Combine(source, name)) || new FileInfo(Path.Combine(source, name)).Length < 1024)
                throw new InvalidDataException("所选目录缺少有效大小的 " + name + "。");
        string parent = Path.Combine(support, "Content");
        Directory.CreateDirectory(parent);
        string pending = Path.Combine(parent, "ra2-pending-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(pending);
        string inventory = "Copy hashes only; no authenticity claim.\r\n";
        foreach (string name in new[] { "ra2.mix", "language.mix", "theme.mix" })
        {
            string src = Path.Combine(source, name);
            if (!File.Exists(src)) continue;
            string before = Hash(src);
            string dst = Path.Combine(pending, name);
            // Copy never writes to the source and never overwrites an existing file.
            File.Copy(src, dst, false);
            if (before != Hash(dst)) throw new InvalidDataException("资源复制校验失败：" + name);
            inventory += name + " " + before + "\r\n";
        }
        File.WriteAllText(Path.Combine(pending, "import-complete.txt"), inventory);
        string target = Path.Combine(parent, "ra2");
        if (Directory.Exists(target))
            Directory.Move(target, Path.Combine(parent, "ra2-previous-" + Guid.NewGuid().ToString("N")));
        Directory.Move(pending, target);
    }
}

internal sealed class ImportForm : Form
{
    readonly Label status;
    readonly Button choose;
    readonly string support;
    bool importing;

    internal ImportForm(string supportPath)
    {
        support = supportPath;
        Text = "RA2 Lab · 本机资源准备";
        Width = 580; Height = 260;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        var notice = new Label { Left = 24, Top = 24, Width = 520, Height = 80,
            Text = "请选择你有权使用的红警2游戏资源目录。\r\n需要 ra2.mix 和 language.mix；theme.mix 为可选音乐。\r\n程序只复制资源到独立数据目录，不修改源文件。" };
        status = new Label { Left = 24, Top = 112, Width = 520, Height = 42, Text = "首次准备完成后，下次可直接启动。" };
        choose = new Button { Left = 24, Top = 166, Width = 180, Height = 32, Text = "选择本机资源目录…" };
        choose.Click += async delegate
        {
            using (var picker = new FolderBrowserDialog { Description = "选择包含 ra2.mix 和 language.mix 的目录", ShowNewFolderButton = false })
            {
                if (picker.ShowDialog(this) != DialogResult.OK) return;
                importing = true; choose.Enabled = false;
                status.Text = "正在复制并校验，请稍候…";
                try
                {
                    string selected = picker.SelectedPath;
                    await Task.Run(delegate { ResourceStore.Import(selected, support); });
                    DialogResult = DialogResult.OK;
                    Close();
                }
                catch (Exception e) { status.Text = e.Message; }
                finally { importing = false; choose.Enabled = true; }
            }
        };
        FormClosing += delegate(object sender, FormClosingEventArgs e) { if (importing && DialogResult != DialogResult.OK) e.Cancel = true; };
        Controls.Add(notice); Controls.Add(status); Controls.Add(choose);
    }
}

internal static class Bootstrap
{
    [STAThread]
    static int Main()
    {
        bool owns;
        using (var gate = new Mutex(true, "Local\\RA2Lab-Desktop", out owns))
        {
            if (!owns) return 0;
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            string root = AppDomain.CurrentDomain.BaseDirectory;
            string support = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "RA2Lab", "Support");
            try
            {
                if (!ResourceStore.Ready(support))
                    using (var form = new ImportForm(support))
                        if (form.ShowDialog() != DialogResult.OK) return 0;
                string game = Path.Combine(root, "engine", "RA2Engine.exe");
                var start = new ProcessStartInfo(game);
                start.UseShellExecute = false;
                start.WorkingDirectory = Path.Combine(root, "engine");
                start.EnvironmentVariables["DOTNET_ROOT"] = Path.Combine(root, "runtime");
                start.EnvironmentVariables["DOTNET_ROOT_X64"] = Path.Combine(root, "runtime");
                start.EnvironmentVariables["DOTNET_MULTILEVEL_LOOKUP"] = "0";
                start.EnvironmentVariables.Remove("MOD_SEARCH_PATHS");
                start.EnvironmentVariables.Remove("ENGINE_DIR");
                start.Arguments = "Game.Mod=ra2 \"Engine.SupportDir=" + support + "\"";
                using (var process = Process.Start(start))
                {
                    if (process == null) throw new InvalidOperationException("无法创建游戏进程。");
                    process.WaitForExit();
                    return process.ExitCode;
                }
            }
            catch (Exception e)
            {
                MessageBox.Show(e.Message, "RA2 Lab 启动失败", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return 1;
            }
        }
    }
}
