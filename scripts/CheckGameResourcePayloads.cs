using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using OpenRA;
using OpenRA.GameRules;

// CPU-only resource decoding. Never initializes Sound, Renderer, World or a load screen.
class CheckGameResourcePayloads
{
    static IEnumerable<string> SoundNames(SoundInfo info, Dictionary<string, string[]> events)
    {
        var variants = info.Prefixes.Keys.Union(info.Variants.Keys).ToArray();
        if (variants.Length == 0) variants = new[] { "" };
        foreach (var evt in events)
        foreach (var variant in variants)
        {
            var prefixes = !info.DisablePrefixes.Contains(evt.Key) && info.Prefixes.TryGetValue(variant, out var p) ? p : new[] { info.DefaultPrefix };
            var suffixes = !info.DisableVariants.Contains(evt.Key) && info.Variants.TryGetValue(variant, out var s) ? s : new[] { info.DefaultVariant };
            foreach (var prefix in prefixes)
            foreach (var suffix in suffixes)
            foreach (var clip in evt.Value)
                if (!string.IsNullOrEmpty(clip)) yield return prefix + clip + suffix;
        }
    }

    static int Main(string[] args)
    {
        Platform.OverrideEngineDir(args[0]);
        Platform.OverrideSupportDir(args[1]);
        Log.AddChannel("debug", null); Log.AddChannel("perf", null);
        try
        {
            Game.InitializeSettings(Arguments.Empty);
            var installed = new InstalledMods(new[] { Path.Combine(args[0], "mods") }, Array.Empty<string>());
            using var mod = new ModData(installed["ra2"], installed);
            Game.ModData = mod;
            var fs = mod.DefaultFileSystem;
            // Resolve format readers through the mod's own load context. Direct Cnc/Common
            // references would make duplicate trait identities in this pinned plugin loader.
            var vxlType = mod.ObjectCreator.FindType("VxlReader");
            var hvaType = mod.ObjectCreator.FindType("HvaReader");
            var failures = new List<string>();
            int modelPairs = 0, audioDecoded = 0, fontHeaders = 0;
            foreach (var entry in mod.DefaultRules.ModelSequences)
            foreach (var sequence in entry.Value.Value.Nodes)
            {
                var names = (sequence.Value.Value ?? entry.Key).Split(',').Select(x => x.Trim()).ToArray();
                var vxlName = names[0] + ".vxl";
                var hvaName = (names.Length > 1 ? names[1] : names[0]) + ".hva";
                try
                {
                    using var vs = fs.Open(vxlName);
                    using var hs = fs.Open(hvaName);
                    var vxl = Activator.CreateInstance(vxlType, new object[] { vs });
                    var hva = Activator.CreateInstance(hvaType, new object[] { hs, hvaName });
                    uint limbs = (uint)vxlType.GetField("LimbCount").GetValue(vxl);
                    uint hvaLimbs = (uint)hvaType.GetField("LimbCount").GetValue(hva);
                    uint frameCount = (uint)hvaType.GetField("FrameCount").GetValue(hva);
                    if (limbs == 0 || frameCount == 0 || limbs != hvaLimbs)
                        throw new InvalidDataException("Model/animation limb mismatch");
                    modelPairs++;
                }
                catch (Exception e) { failures.Add(vxlName + "/" + hvaName + ": " + e.GetType().Name); }
            }
            var sounds = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var voice in mod.DefaultRules.Voices.Where(x => !x.Key.StartsWith("^"))) sounds.UnionWith(SoundNames(voice.Value, voice.Value.Voices));
            foreach (var notice in mod.DefaultRules.Notifications.Values) sounds.UnionWith(SoundNames(notice, notice.Notifications));
            foreach (var weapon in mod.DefaultRules.Weapons.Values)
                sounds.UnionWith((weapon.Report ?? Array.Empty<string>()).Concat(weapon.StartBurstReport ?? Array.Empty<string>()).Concat(weapon.AfterFireSound ?? Array.Empty<string>()));
            foreach (var name in sounds.OrderBy(x => x))
            {
                try
                {
                    using var input = fs.Open(name);
                    bool decoded = false;
                    foreach (var loader in mod.SoundLoaders)
                    {
                        input.Position = 0;
                        if (!loader.TryParseSound(input, out var format)) continue;
                        using (format)
                        using (var pcm = format.GetPCMInputStream())
                        {
                            var buffer = new byte[16384];
                            long bytes = 0;
                            int count;
                            while ((count = pcm.Read(buffer, 0, buffer.Length)) > 0) bytes += count;
                            if (bytes == 0 || format.SampleRate <= 0) throw new InvalidDataException("Empty PCM");
                        }
                        decoded = true;
                        audioDecoded++;
                        break;
                    }
                    if (!decoded) throw new InvalidDataException("Unsupported sound format");
                }
                catch (Exception e) { failures.Add(name + ": " + e.GetType().Name); }
            }
            foreach (var name in new[] { "common|FreeSans.ttf", "common|FreeSansBold.ttf" })
            {
                try
                {
                    using var input = fs.Open(name);
                    var header = new byte[4];
                    if (input.Read(header, 0, 4) != 4 || header[0] != 0 || header[1] != 1 || input.Length < 1024)
                        throw new InvalidDataException("Unexpected TrueType header");
                    fontHeaders++;
                }
                catch (Exception e) { failures.Add(name + ": " + e.GetType().Name); }
            }
            var music = mod.DefaultRules.Music.Values.Select(x => new { x.Filename, Present = fs.Exists(x.Filename) }).ToArray();
            using var audioPackage = mod.ModFiles.OpenPackage("audio.bag");
            var catalog = audioPackage?.Contents.OrderBy(x => x).ToArray();
            Console.WriteLine(JsonSerializer.Serialize(new { ModelPairsDecoded = modelPairs, AudioFilesDecoded = audioDecoded,
                FontHeadersReadable = fontHeaders, Failures = failures, OptionalMusic = music, SoundCatalog = catalog,
                Scope = "Default model sequences, declared voice/notification variants, weapon reports, two font headers. No rendering, playback, simulation, actor effect sounds or map-specific overrides." },
                new JsonSerializerOptions { WriteIndented = true }));
            return failures.Count == 0 ? 0 : 1;
        }
        finally { Log.Dispose(); }
    }
}
