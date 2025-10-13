using Microsoft.SqlServer.Server;
using System;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using static System.Net.Mime.MediaTypeNames;
using System.Text;
using System.Collections.Generic;

[assembly: AssemblyVersion("1.0.0.0")]

namespace SQLBuild
{
    public class Functions
    {
        const string con = "context connection=true";
        const int CommandTimeoutSeconds = 300;

        [Microsoft.SqlServer.Server.SqlProcedure]
        public static void BulkInsertTable(string withopt)
        {
            var tableData = new Dictionary<string, string>();
            try
            {
                using (var conn = new SqlConnection(con))
                {
                    conn.Open();
                    string getCsv = "SELECT [Table], [Data] FROM [dbo].[bulkinsert] ORDER BY [Order]";

                    using (var cmd = conn.CreateCommand())
                    {
                        cmd.CommandText = getCsv;
                        cmd.CommandTimeout = CommandTimeoutSeconds;
                        var reader = cmd.ExecuteReader();
                        while (reader.Read())
                        {
                            var path = Path.GetTempFileName();
                            var tableName = reader.GetString(0);
                            var csvData = reader.GetString(1);
                            File.WriteAllText(path, csvData);
                            tableData.Add(tableName, path);
                        }
                        reader.Close();
                    }


                    conn.Close();
                }

                foreach (var item in tableData)
                {
                    using (var conn = new SqlConnection(con))
                    {
                        conn.Open();
                        // using (var cmd = new SqlCommand("SELECT 1", conn))
                        // {
                        //     cmd.ExecuteNonQuery();
                        // }

                        using (var bulkCmd = conn.CreateCommand())
                        {
                            var raw = File.ReadAllText(item.Value);
                            bulkCmd.CommandText = $"BULK INSERT {item.Key} FROM '{item.Value}' WITH ({withopt});";
                            bulkCmd.CommandTimeout = CommandTimeoutSeconds;
                            try
                            {
                                bulkCmd.ExecuteNonQuery();
                            }
                            catch (Exception ex)
                            {
                                SqlContext.Pipe.Send($"Error for {item.Key}, {bulkCmd.CommandText}: {ex.Message}");
                                throw;
                            }
                        }

                        conn.Close();
                    }
                }
            }
            finally
            {
                foreach (var path in tableData.Values)
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