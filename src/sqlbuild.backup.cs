using Microsoft.SqlServer.Server;
using System;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using static System.Net.Mime.MediaTypeNames;
using System.Text;

[assembly: AssemblyVersion("1.0.0.0")]

namespace SQLBuild
{
    public class Functions
    {
        const string con = "context connection=true";

        [Microsoft.SqlServer.Server.SqlProcedure]
        public static void CreateBackup(string name, out byte[] backup, bool compress = false)
        {
            using (var conn = new SqlConnection(con))
            {
                var path = Path.GetTempFileName();
                string backupDb = $"BACKUP DATABASE [{name}] TO DISK = '{path}' WITH INIT";
                using (var cmd = conn.CreateCommand())
                {
                    cmd.CommandText = backupDb;
                    conn.Open();
                    cmd.ExecuteNonQuery();
                    conn.Close();
                    backup = File.ReadAllBytes(path);
                    File.Delete(path);

                    if (compress)
                    {
                        using (var ms = new MemoryStream())
                        {
                            using (var zip = new GZipStream(ms, CompressionMode.Compress))
                            {
                                zip.Write(backup, 0, backup.Length);
                            }
                            backup = ms.ToArray();
                        }
                    }
                }
            }
        }
    }
}