using System;
using System.IO;
using Microsoft.Build.Framework;
using Microsoft.Build.Utilities;
using Microsoft.Data.SqlClient;

namespace sqlbuild.tasks
{
    public class RestoreBackup : Task
    {
        [Required]
        public string ConnectionString { get; set; }

        [Required]
        public string BackupPath { get; set; }

        [Required]
        public string DatabaseName { get; set; }

        public override bool Execute()
        {
            try
            {
                var str = new SqlConnectionStringBuilder(ConnectionString);
                using (var connection = new SqlConnection(ConnectionString))
                {
                    connection.Open();
                    var log = new Action<string, int>((msg, level) => Log.LogMessage(msg, level > 0 ? MessageImportance.High : MessageImportance.Normal));
                    using (var iso = new IsolatedSqlBuild(connection, log))
                    {
                        SqlBuild.RestoreBackup(connection, DatabaseName, BackupPath);
                        Log.LogMessage("SQLBUILD: Backup restored as " + DatabaseName, MessageImportance.High);
                    }
                }
            }
            catch (Exception ex)
            {
                Log.LogErrorFromException(ex);
                return false;
            }
            return true;
        }
    }
}
