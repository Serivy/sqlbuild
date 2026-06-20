using System;
using Microsoft.Build.Framework;
using Microsoft.Build.Utilities;
using Microsoft.Data.SqlClient;


namespace sqlbuild.tasks
{
    public class IsolatedSqlBuild : IDisposable
    {
        private readonly SqlConnection _connection;
        private readonly Action<string, int> _log;

        private readonly string _uniqueId;
        private readonly string _originalDb;
        public IsolatedSqlBuild(SqlConnection connection, Action<string, int> log = null)
        {
            _connection = connection;
            _log = log;
            var str = new SqlConnectionStringBuilder(connection.ConnectionString);
            _uniqueId = "sqlbuild_" + DateTime.Now.ToString("yyyyMMddHHmmss") + "_" + Guid.NewGuid().ToString("N");
            _originalDb = str.InitialCatalog;

            new SqlCommand(string.Format(SqlBuild.qryCreate, _uniqueId), connection).ExecuteNonQuery();
            new SqlCommand(string.Format(SqlBuild.qryUse, _uniqueId), connection).ExecuteNonQuery();

            if (log != null) {
                log("SQLBUILD: Installing on " + connection.Database, 1);
            }
            SqlBuild.InstallAsm(connection);
        }

        public void Dispose()
        {
            new SqlCommand(string.Format(SqlBuild.qryUse, _originalDb), _connection).ExecuteNonQuery();
            new SqlCommand(string.Format(SqlBuild.qryDelete, _uniqueId), _connection).ExecuteNonQuery();
            if (_log != null) {
                _log("SQLBUILD: Isolated environment cleaned up", 0);
            }
        }
    }
}
