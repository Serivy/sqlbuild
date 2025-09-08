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
        public static void RestoreBackup(string name, byte[] backup, bool compressed = false)
        {
            using (var conn = new SqlConnection(con))
            {
                string restoreDb = @"
declare @data nvarchar(max), @log nvarchar(max), @logFile nvarchar(max), @dataFile nvarchar(max), @restore nvarchar(max); 
select @data = cast(serverproperty('InstanceDefaultDataPath') as nvarchar(max)), @log = cast(serverproperty('InstanceDefaultLogPath') as nvarchar(max))
declare @files table(LogicalName NVARCHAR(128) NOT NULL, PhysicalName NVARCHAR(260) NOT NULL,Type CHAR(1) NOT NULL,FileGroupName NVARCHAR(120) NULL,Size NUMERIC(20, 0) NOT NULL,MaxSize NUMERIC(20, 0) NOT NULL,FileId BIGINT NULL,CreateLSN NUMERIC(25, 0) NULL,DropLSN NUMERIC(25, 0) NULL,UniqueID UNIQUEIDENTIFIER NULL,ReadOnlyLSN NUMERIC(25, 0) NULL,ReadWriteLSN NUMERIC(25, 0) NULL,BackupSizeInBytes BIGINT NULL,SourceBlockSize INT NULL,FileGroupId INT NULL,LogGroupGUID UNIQUEIDENTIFIER NULL,DifferentialBaseLSN NUMERIC(25, 0) NULL,DifferentialBaseGUID UNIQUEIDENTIFIER NULL,IsReadOnly BIT NULL,IsPresent BIT NULL,TDEThumbprint VARBINARY(32) NULL, SnapshotURL NVARCHAR(360))
insert into @files
exec ('RESTORE FILELISTONLY FROM DISK = '''+@bak+'''')
exec ('if db_id('''+ @name +''') is not null begin ALTER DATABASE ['+ @name +'] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE ['+ @name +']; end;')
select @dataFile = (select top 1 LogicalName from @files Where Type = 'D'), @logFile = (select top 1 LogicalName from @files Where Type = 'L'), @restore = 'RESTORE DATABASE ['+@name+'] FROM DISK = '''+@bak+''' WITH FILE = 1, MOVE ''' + @dataFile + ''' TO ''' + @data + @name + '_Data.mdf'',MOVE '''+ @logFile +''' TO '''+ @log + @name + '_Log.mdf'',  NOUNLOAD, REPLACE, STATS = 5'
exec(@restore)";
                var path = Path.GetTempFileName();

                if (compressed)
                {
                    using (var ms = new MemoryStream(backup))
                    {
                        using (var zip = new GZipStream(ms, CompressionMode.Decompress))
                        {
                            using (var outms = new MemoryStream())
                            {
                                zip.CopyTo(outms);
                                backup = outms.ToArray();
                            }
                        }
                    }
                }

                File.WriteAllBytes(path, backup);
                try
                {
                    using (var cmd = conn.CreateCommand())
                    {
                        cmd.CommandText = restoreDb;
                        cmd.Parameters.AddWithValue("@name", SqlDbType.NVarChar).Value = name;
                        cmd.Parameters.AddWithValue("@bak", SqlDbType.NVarChar).Value = path;
                        conn.Open();
                        cmd.ExecuteNonQuery();
                        conn.Close();
                    }
                    
                }
                finally
                {
                    if (File.Exists(path))
                    {
                        File.Delete(path);
                    }
                }
            }
        }
    }
}