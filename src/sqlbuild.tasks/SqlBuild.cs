using System;
using System.IO;
using Microsoft.Build.Framework;
using Microsoft.Build.Utilities;
using Microsoft.Data.SqlClient;


namespace sqlbuild.tasks
{
    public static class SqlBuild
    {
        const string install = @"
print DB_NAME()
print @@version
print CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion'))

declare @hash varbinary(64) = CONVERT(varbinary(64), '{0}', 2);

-- Trusted assemblies are global, see if it exists and if not add it.
if OBJECT_ID(N'master.sys.trusted_assemblies') is null begin alter database master set trustworthy on end
if not exists (select 1 from sys.trusted_assemblies where hash = @hash) begin
    exec sp_add_trusted_assembly @hash, N'sqlbuild, version=0.0.0.0, culture=neutral, publickeytoken=null, processorarchitecture=msil';
end

Exec sp_configure 'show advanced options', 1; RECONFIGURE; exec sp_configure 'clr enabled', 1; RECONFIGURE; EXEC sp_configure 'show advanced options', 0; RECONFIGURE;

create assembly sqlbuild authorization [dbo] from 0x{1}
with permission_set = unsafe;

declare @dynsql nvarchar(max);

set @dynsql = 'create procedure RestoreBackup(@name nvarchar(max), @backup varbinary(max), @compressed bit = 0) as external name sqlbuild.[SQLBuild.Functions].RestoreBackup'
execute sp_executesql @dynsql
-- 
set @dynsql = 'create procedure CreateBackup (@name nvarchar(max), @backup varbinary(max) output, @compress bit = 0) as external name sqlbuild.[SQLBuild.Functions].[CreateBackup]'
execute sp_executesql @dynsql

";

        public static string qryCreate = "create database [{0}];";
        public static string qryUse = "use [{0}];";
        public static string qryDelete = "ALTER DATABASE [{0}] SET OFFLINE WITH ROLLBACK IMMEDIATE; ALTER DATABASE [{0}] SET ONLINE; DROP DATABASE [{0}];";

        public static bool InstallAsm(SqlConnection connection)
        {
            var setupQuery = string.Format(install, SqlBuildBackupAsm.Hash, SqlBuildBackupAsm.Hex);
            new SqlCommand(setupQuery, connection).ExecuteNonQuery();
            return true;
        }

        public static bool CreateBackup(SqlConnection connection, string DatabaseName, string BackupPath)
        {
            var cmd = connection.CreateCommand();
            var param = new SqlParameter("@backup", System.Data.SqlDbType.VarBinary, -1);
            param.Direction = System.Data.ParameterDirection.Output;
            cmd.CommandText = "dbo.CreateBackup";
            cmd.CommandType = System.Data.CommandType.StoredProcedure;
            cmd.Parameters.Add(new SqlParameter("@name", DatabaseName));
            cmd.Parameters.Add(param);
            cmd.ExecuteNonQuery();
            File.WriteAllBytes(BackupPath, (byte[])param.Value);
            return true;
        }

        public static void RestoreBackup(SqlConnection connection, string DatabaseName, string BackupPath)
        {
            var cmd = connection.CreateCommand();
            var backupBytes = File.ReadAllBytes(BackupPath);
            cmd.CommandText = "exec dbo.RestoreBackup @name = '" + DatabaseName + "', @backup = @data";
            cmd.Parameters.Add(new SqlParameter("@data", backupBytes));
            cmd.ExecuteNonQuery();
        }
    }
}
