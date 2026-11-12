using System;
using System.IO;
using System.Reflection;
using System.Collections.Generic;
using System.Text.Json;
using OpenRA.Mods.Cnc.FileSystem;
class Program {
 static readonly string[] KnownPackages = { "multi.mix", "audio.mix", "cache.mix", "cameo.mix", "conquer.mix", "generic.mix", "isogen.mix", "isosnow.mix", "isotemp.mix", "isourb.mix", "load.mix", "local.mix", "neutral.mix", "sidec01.mix", "sidec02.mix", "sno.mix", "snow.mix", "tem.mix", "temperat.mix", "theme.mix", "urb.mix", "urban.mix" };
 static void Check(Stream s, string name, List<object> results, int depth) {
   if (depth > 8) throw new InvalidDataException("Nested MIX depth limit exceeded");
   using var reader=new BinaryReader(s,System.Text.Encoding.UTF8,true);
   s.Position=0;
   bool classic=reader.ReadUInt16()!=0;
   bool encrypted=!classic && (reader.ReadUInt16()&2)!=0;
   long start; Stream header=s;
   if(encrypted) {
    object[] p={s,4L,0L};
    header=(Stream)typeof(MixLoader.MixFile).GetMethod("DecryptHeader",BindingFlags.NonPublic|BindingFlags.Static).Invoke(null,p);
    start=(long)p[2];
   } else { s.Position=classic?0:4; start=0; }
   using var br=new BinaryReader(header,System.Text.Encoding.UTF8,true);
   int count=br.ReadUInt16(); uint size=br.ReadUInt32();
   if(!encrypted) start=(classic?0:4)+6+count*12;
   var hashes=new HashSet<uint>(); int duplicates=0;
   for(int i=0;i<count;i++) {
    uint hash=br.ReadUInt32(),offset=br.ReadUInt32(),length=br.ReadUInt32();
    if(!hashes.Add(hash)) duplicates++;
    if((long)offset+length>size || start+(long)offset+length>s.Length) throw new InvalidDataException(name+": entry outside data bounds");
   }
   if(start+(long)size>s.Length || duplicates!=0) throw new InvalidDataException(name+": invalid size or duplicate hashes");
   if(encrypted) header.Dispose();
   results.Add(new {Name=name,Encrypted=encrypted,Entries=count,DuplicateHashes=duplicates,DeclaredDataSize=size,Scope="Index bounds and known nested MIX only; no checksum, authenticity or asset decoding validation"});
   s.Position=0;
   using var package=new MixLoader.MixFile(s,name,KnownPackages);
   foreach(var child in KnownPackages) {
    using var content=package.GetStream(child);
    if(content!=null) Check(content,name+"/"+child,results,depth+1);
   }
 }
 static void Main(string[] args) {
  OpenRA.Log.AddChannel("debug", null);
  try {
  var results=new List<object>();
  foreach(var path in args) {
   using var s=File.OpenRead(path);
   Check(s,Path.GetFileName(path),results,0);
  }
  Console.WriteLine(JsonSerializer.Serialize(results,new JsonSerializerOptions{WriteIndented=true}));
  } finally { OpenRA.Log.Dispose(); }
 }
}
