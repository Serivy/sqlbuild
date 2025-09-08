using System;

namespace SqlBuild.BackupExample
{
    class Program
    {
        static void Main(string[] args)
        {
            var connectionString = args.Length > 0 ? args[0] : "Server=localhost;Integrated Security=true;";
            var databaseName = args.Length > 1 ? args[1] : "model";
            var backupPath = args.Length > 2 ? args[2] : "obj/model_backup.bak";
            var compress = args.Length > 3 && bool.TryParse(args[3], out var result) && result;

            Console.WriteLine($"Restoring up database '{databaseName}' from '{backupPath}' (compress={compress}) connection='{connectionString}'");

            RestoreDatabase(connectionString, databaseName, backupPath, compress);
        }

        static void RestoreDatabase(string connectionString, string database, string backupPath, bool compressed = false)
        {
            var backupBytes = System.IO.File.ReadAllBytes(backupPath);
            using (var conn = new System.Data.SqlClient.SqlConnection(connectionString))
            {
                conn.InfoMessage += (sender, e) => Console.WriteLine(e.Message);
                conn.FireInfoMessageEventOnUserErrors = true;
                conn.Open();
                using (var command = conn.CreateCommand())
                {
                    command.CommandText = @"{sqlbuild.restore.sql}";
                    command.Parameters.Add(new System.Data.SqlClient.SqlParameter("@backup", backupBytes));
                    command.Parameters.Add(new System.Data.SqlClient.SqlParameter("@name", database));
                    command.Parameters.Add(new System.Data.SqlClient.SqlParameter("@compressed", compressed));
                    command.ExecuteNonQuery();
                }
                conn.Close();
            }
        }
    }
}