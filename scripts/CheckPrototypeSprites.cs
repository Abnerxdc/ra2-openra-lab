using System;
using System.IO;
using System.Collections.Generic;
using System.Text.Json;
using OpenRA.Mods.Common.SpriteLoaders;

// CPU-only fixed-engine PNG decoding. Does not initialize Game, graphics or sound.
class CheckPrototypeSprites
{
    static void Main(string[] args)
    {
        var results = new List<object>();
        foreach (var path in args)
        {
            using var input = File.OpenRead(path);
            if (!new PngSheetLoader().TryParseSprite(input, Path.GetFileName(path), out var frames, out _))
                throw new InvalidDataException("PNG decoder rejected sprite");
            if (frames.Length != 1) throw new InvalidDataException("Expected one static prototype frame");
            var frame = frames[0];
            if (frame.Size.Width != 1254 || frame.Size.Height != 1254 || frame.Data.Length != 1254 * 1254 * 4)
                throw new InvalidDataException("Expected 1254 square RGBA prototype");
            int transparent = 0, visible = 0;
            for (int i = 3; i < frame.Data.Length; i += 4)
            {
                if (frame.Data[i] == 0) transparent++;
                if (frame.Data[i] > 0) visible++;
            }
            if (transparent == 0 || visible == 0) throw new InvalidDataException("Missing transparent background or vehicle pixels");
            results.Add(new { Name = Path.GetFileName(path), Frames = frames.Length, Width = frame.Size.Width,
                Height = frame.Size.Height, Type = frame.Type.ToString(), TransparentPixels = transparent, VisiblePixels = visible });
        }
        Console.WriteLine(JsonSerializer.Serialize(results, new JsonSerializerOptions { WriteIndented = true }));
    }
}
