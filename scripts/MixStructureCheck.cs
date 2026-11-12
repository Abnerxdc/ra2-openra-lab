using System;
using System.IO;
using System.Reflection;
using System.Collections.Generic;
using System.Text.Json;
using OpenRA.Mods.Cnc.FileSystem;
class Program {
 static void Main(string[] args) {
  var results=new List<object>();
  foreach(var path in args) {
   using var s=File.OpenRead(path); using var reader=new BinaryReader(s);
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
   int invalid=0; var hashes=new HashSet<uint>(); int duplicates=0;
   for(int i=0;i<count;i++) { uint hash=br.ReadUInt32(),offset=br.ReadUInt32(),length=br.ReadUInt32(); if(!hashes.Add(hash)) duplicates++; if(start+(long)offset+length>s.Length) invalid++; }
   if(start+(long)size>s.Length || invalid!=0) throw new InvalidDataException(Path.GetFileName(path));
   results.Add(new {Name=Path.GetFileName(path),Encrypted=encrypted,Entries=count,InvalidRanges=invalid,DuplicateHashes=duplicates,DeclaredDataSize=size,Scope="Header/index bounds only; no authenticity or payload validation"});
   if(encrypted) header.Dispose();
  }
  Console.WriteLine(JsonSerializer.Serialize(results,new JsonSerializerOptions{WriteIndented=true}));
 }
}
