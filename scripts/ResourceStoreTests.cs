using System;
using System.IO;

// Console test entry only. Does not instantiate Bootstrap, ImportForm, a renderer or audio.
internal static class ResourceStoreTests
{
    static void Require(bool value, string message)
    {
        if (!value) throw new Exception(message);
    }

    static int Main(string[] args)
    {
        string root = args[0];
        string source = Path.Combine(root, "source");
        string support = Path.Combine(root, "support");
        Directory.CreateDirectory(source);
        byte[] bytes = new byte[2048];
        for (int i = 0; i < bytes.Length; i++) bytes[i] = (byte)(i % 251);
        foreach (string name in ResourceStore.Required) File.WriteAllBytes(Path.Combine(source, name), bytes);
        string before = ResourceStore.Hash(Path.Combine(source, "ra2.mix"));
        Require(!ResourceStore.Ready(support), "Empty support directory must not be ready");
        ResourceStore.Import(source, support);
        Require(ResourceStore.Ready(support), "Successful base copy should be ready without optional music");
        Require(ResourceStore.Hash(Path.Combine(source, "ra2.mix")) == before, "Source changed");
        Require(ResourceStore.Hash(Path.Combine(support, "Content", "ra2", "ra2.mix")) == before, "Copied bytes differ");
        string marker = File.ReadAllText(Path.Combine(support, "Content", "ra2", "import-complete.txt"));
        Require(!marker.Contains(source), "Import marker must not store source paths");
        string missing = Path.Combine(root, "missing");
        Directory.CreateDirectory(missing);
        bool rejected = false;
        try { ResourceStore.Import(missing, support); }
        catch (InvalidDataException) { rejected = true; }
        Require(rejected && ResourceStore.Ready(support), "Failed validation damaged ready content");
        ResourceStore.Import(source, support);
        Require(Directory.GetDirectories(Path.Combine(support, "Content"), "ra2-previous-*").Length == 1,
            "Reimport must preserve previous content");
        File.WriteAllBytes(Path.Combine(source, "theme.mix"), bytes);
        ResourceStore.Import(source, support);
        Require(File.Exists(Path.Combine(support, "Content", "ra2", "theme.mix")), "Optional music copy missing");
        Console.WriteLine("PASS: base copy, hashes, source immutability, optional music, failure preservation, backup and path-free marker.");
        return 0;
    }
}
