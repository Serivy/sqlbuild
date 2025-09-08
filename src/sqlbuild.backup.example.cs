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

            Console.WriteLine($"Backing up database '{databaseName}' to '{backupPath}' (compress={compress}) connection='{connectionString}'");

            BackupDatabase(connectionString, databaseName, backupPath, compress);
        }

        static void BackupDatabase(string connectionString, string database, string backupPath, bool compress = false)
        {
            using (var conn = new System.Data.SqlClient.SqlConnection(connectionString))
            {
                conn.InfoMessage += (sender, e) => Console.WriteLine(e.Message);
                conn.FireInfoMessageEventOnUserErrors = true;
                conn.Open();

                using (var command = conn.CreateCommand())
                {
                    command.CommandText = @"{sqlbuild.backup.sql}";

                    var nameParam = new System.Data.SqlClient.SqlParameter("@name", database);
                    var backupParam = new System.Data.SqlClient.SqlParameter("@backup", System.Data.SqlDbType.VarBinary, -1)
                    {
                    Direction = System.Data.ParameterDirection.Output
                    };
                    var compressParam = new System.Data.SqlClient.SqlParameter("@compress", compress);

                    command.Parameters.Add(nameParam);
                    command.Parameters.Add(backupParam);
                    command.Parameters.Add(compressParam);

                    command.ExecuteNonQuery();

                    var backupBytes = backupParam.Value as byte[];
                    if (backupBytes != null)
                    {
                        System.IO.File.WriteAllBytes(backupPath, backupBytes);
                    }
                }
                conn.Close();
            }
        }
    }
}