using System.Reflection;
using Moq;
using Microsoft.Build.Framework;
using Microsoft.Data.SqlClient;
using sqlbuild.tasks;

namespace sqlbuild.test;

public class SqlBackupTests
{
    const string conn2 = "Server=127.0.0.1,31433;Database=master;User Id=sa;Password=yourStrong(!)Password;trustservercertificate=true;";
    const string conn = "Server=(localdb)\\MSSQLLocalDB;Database=master;Integrated Security=true;";

    [Fact]
    public void BackupAndRestore()
    {
        var srdDb = "sqlbuildtest";
        var buildEngine = new Mock<IBuildEngine>();
        buildEngine.Setup(x => x.LogErrorEvent(It.IsAny<BuildErrorEventArgs>()))
            .Callback<BuildErrorEventArgs>(x => throw new Exception(x.Message));
        buildEngine.Setup(x => x.LogMessageEvent(It.IsAny<BuildMessageEventArgs>()))
            .Callback<BuildMessageEventArgs>(x => Console.WriteLine(x.Message));
        
        var sourcePath = Assembly.GetAssembly(GetType())?.Location ?? ".";
        while (!Path.GetFileName(sourcePath)?.Equals("src") ?? false)
        {
            sourcePath = Path.GetDirectoryName(sourcePath) ?? ".";
        }
        var backupPath = Path.Combine(sourcePath, "sqlbuild.test", "obj", "backup.bak");

        var connectionString = conn;

        // setup
        using (var connection = new SqlConnection(connectionString))
        {
            connection.Open();
            new SqlCommand($"IF EXISTS (SELECT 1 FROM sys.databases WHERE name = '{srdDb}') BEGIN ALTER DATABASE [{srdDb}] SET OFFLINE WITH ROLLBACK IMMEDIATE; ALTER DATABASE [{srdDb}] SET ONLINE; DROP DATABASE [{srdDb}]; END", connection).ExecuteNonQuery(); 
            new SqlCommand($"create database [{srdDb}]", connection).ExecuteNonQuery();
            new SqlCommand($"use [{srdDb}]", connection).ExecuteNonQuery();
            new SqlCommand($"create table TestTable (Id int, Name nvarchar(50))", connection).ExecuteNonQuery();
            new SqlCommand($"insert into TestTable (Id, Name) values (1, 'Test')", connection).ExecuteNonQuery();
        }

        // create backup
        var task = new CreateBackup
        {
            BuildEngine = buildEngine.Object,
            BackupPath = backupPath,
            DatabaseName = srdDb,
            ConnectionString = connectionString
        };
        task.Execute();

        // clear
        using (var connection = new SqlConnection(connectionString))
        {
            connection.Open();
            new SqlCommand($"IF EXISTS (SELECT 1 FROM sys.databases WHERE name = '{srdDb}') BEGIN ALTER DATABASE [{srdDb}] SET OFFLINE WITH ROLLBACK IMMEDIATE; ALTER DATABASE [{srdDb}] SET ONLINE; DROP DATABASE [{srdDb}]; END", connection).ExecuteNonQuery(); 
        }

        // restore backup
        var restoreBackup = new RestoreBackup
        {
            BuildEngine = buildEngine.Object,
            ConnectionString = connectionString,
            BackupPath = backupPath,
            DatabaseName = srdDb
        };
        restoreBackup.Execute();

        using (var connection = new SqlConnection(connectionString))
        {
            connection.Open();
            var rst = new SqlCommand($"select * from {srdDb}.dbo.TestTable", connection).ExecuteReader(); 
            Assert.True(rst.HasRows);
            Assert.True(rst.Read());
            Assert.Equal(1, rst.GetInt32(0));
            Assert.Equal("Test", rst.GetString(1));
            rst.Close();
            new SqlCommand($"IF EXISTS (SELECT 1 FROM sys.databases WHERE name = '{srdDb}') BEGIN ALTER DATABASE [{srdDb}] SET OFFLINE WITH ROLLBACK IMMEDIATE; ALTER DATABASE [{srdDb}] SET ONLINE; DROP DATABASE [{srdDb}]; END", connection).ExecuteNonQuery(); 
        }
    }
}
