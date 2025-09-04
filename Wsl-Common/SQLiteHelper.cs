using System;
using System.Collections;
using System.Data;
using System.Collections.Generic;
using System.Runtime.InteropServices;

// cSpell: ignore winsqlite errmsg dflt
public class SQLiteHelper : IDisposable
{
    [DllImport("winsqlite3.dll", CharSet = CharSet.Unicode, EntryPoint = "sqlite3_open16")] private static extern int open(string filename, out IntPtr db);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_extended_result_codes")] private static extern int result_codes(IntPtr db, int onOrOff);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_close_v2")] private static extern int close(IntPtr db);
    [DllImport("winsqlite3.dll", CharSet = CharSet.Unicode, EntryPoint = "sqlite3_prepare16")] private static extern int prepare(IntPtr db, string query, int len, out IntPtr stmt, out IntPtr remainingQuery);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_step")] private static extern int step(IntPtr stmt);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_column_count")] private static extern int column_count(IntPtr stmt);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_column_name16")] private static extern IntPtr column_name(IntPtr stmt, int col);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_column_type")] private static extern int column_type(IntPtr stmt, int col);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_column_double")] private static extern Double column_double(IntPtr stmt, int col);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_column_int")] private static extern int column_int(IntPtr stmt, int col);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_column_int64")] private static extern Int64 column_int64(IntPtr stmt, int col);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_column_text16")] private static extern IntPtr column_text(IntPtr stmt, int col);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_column_blob")] private static extern IntPtr column_blob(IntPtr stmt, int col);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_column_bytes")] private static extern int column_bytes(IntPtr stmt, int col);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_finalize")] private static extern int finalize(IntPtr stmt);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_bind_null")] private static extern int sqlite3_bind_null(IntPtr stmt, int index);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_bind_int")] private static extern int sqlite3_bind_int(IntPtr stmt, int index, int value);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_bind_int64")] private static extern int sqlite3_bind_int64(IntPtr stmt, int index, long value);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_bind_double")] private static extern int sqlite3_bind_double(IntPtr stmt, int index, double value);
    [DllImport("winsqlite3.dll", CharSet = CharSet.Unicode, EntryPoint = "sqlite3_bind_text16")] private static extern int sqlite3_bind_text16(IntPtr stmt, int index, string value, int n, IntPtr free);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_bind_blob")] private static extern int sqlite3_bind_blob(IntPtr stmt, int index, byte[] value, int n, IntPtr free);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_bind_parameter_count")] private static extern int sqlite3_bind_parameter_count(IntPtr stmt);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_bind_parameter_index")] private static extern int sqlite3_bind_parameter_index(IntPtr stmt, string name);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_bind_parameter_name")] private static extern IntPtr sqlite3_bind_parameter_name(IntPtr stmt, int index);
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_errmsg")] private static extern IntPtr sqlite3_errmsg(IntPtr db);

    // Important result codes.
    private const int SQLITE_OK = 0;
    private const int SQLITE_ROW = 100; // step() indicates that at least 1 more row exists.
    private const int SQLITE_DONE = 101; // step() indicates that there are no (more) rows.
                                         // Data type IDs
    private const int SQLITE_INTEGER = 1;
    private const int SQLITE_FLOAT = 2;
    private const int SQLITE_TEXT = 3;
    private const int SQLITE_BLOB = 4;
    private const int SQLITE_NULL = 5;

    // A helper exception to report SQLite result codes that are errors.
    public class SQLiteException : Exception
    {
        private int _nativeErrorCode;
        public int NativeErrorCode { get { return _nativeErrorCode; } set { _nativeErrorCode = value; } }
        public SQLiteException(int code) : this(String.Format("SQLite API call failed with result code {0}.", code), code) { }
        public SQLiteException(string message, int code) : base(string.Format("{0} (result code {1}).", message, code)) { NativeErrorCode = code; }
    }

    private IntPtr _db;

    public string UpdateTimestampColumn { get; set; }

    public bool IsOpen { get { return _db != IntPtr.Zero; } }

    // Internal structure to hold table schema information
    private class TableSchema
    {
        public string TableName { get; set; }
        public List<string> PrimaryKeyColumns { get; set; } = new List<string>();
        public List<string> RegularColumns { get; set; } = new List<string>();
        public List<string> TimestampColumns { get; set; } = new List<string>();
        public List<string> AllColumns { get; set; } = new List<string>();
        public string UpdateTimestampColumn { get; set; }
        public bool HasUpdateTimestamp { get; set; }
    }

    private SQLiteHelper(IntPtr db) { _db = db; }

    public void Dispose()
    {
        Close();
    }

    public void Close()
    {
        if (!IsOpen) return;
        int result = close(_db);
        if (result != SQLITE_OK) throw new SQLiteException(result);
        _db = IntPtr.Zero;
    }

    public string GetLastErrorMessage()
    {
        IntPtr msgPtr = sqlite3_errmsg(_db);
        return Marshal.PtrToStringUTF8(msgPtr);
    }

    public static SQLiteHelper Open(string filename)
    {
        IntPtr db;
        int result = open(filename, out db);
        if (result != SQLITE_OK) throw new SQLiteException(result);
        result = result_codes(db, 1); // report extended result codes by default.
        if (result != SQLITE_OK) throw new SQLiteException(result);
        return new SQLiteHelper(db);
    }

    private static void BindParameter(IntPtr stmt, object arg, int sqliteIndex)
    {
        int result;
        if (arg == null || arg == DBNull.Value)
        {
            result = sqlite3_bind_null(stmt, sqliteIndex);
        }
        else if (arg is Int32 || arg is Int16 || arg is Byte)
        {
            result = sqlite3_bind_int(stmt, sqliteIndex, Convert.ToInt32(arg));
        }
        else if (arg is Int64)
        {
            result = sqlite3_bind_int64(stmt, sqliteIndex, Convert.ToInt64(arg));
        }
        else if (arg is Double || arg is Single || arg is Decimal)
        {
            result = sqlite3_bind_double(stmt, sqliteIndex, Convert.ToDouble(arg));
        }
        else if (arg is String)
        {
            result = sqlite3_bind_text16(stmt, sqliteIndex, (string)arg, -1, new IntPtr(-1)); // -1 means that the string is null-terminated.
        }
        else if (arg is byte[])
        {
            byte[] arr = (byte[])arg;
            result = sqlite3_bind_blob(stmt, sqliteIndex, arr, arr.Length, new IntPtr(-1));
        }
        else
        {
            throw new ArgumentException(String.Format("Cannot bind argument of type {0}.", arg.GetType().FullName));
        }
        if (result != SQLITE_OK) throw new SQLiteException(result);
    }

    private static int BindParameters(IntPtr stmt, object[] args, int startIndex)
    {
        int parameterCount = sqlite3_bind_parameter_count(stmt);
        int consumed = 0;

        for (int i = 0; i < parameterCount && (startIndex + consumed) < args.Length; i++)
        {
            object arg = args[startIndex + consumed];
            BindParameter(stmt, arg, i + 1);
            consumed++;
        }

        return consumed;
    }

    private static void BindParameters(IntPtr stmt, IDictionary namedArgs)
    {
        if (namedArgs == null || namedArgs.Count == 0) return;

        int parameterCount = sqlite3_bind_parameter_count(stmt);

        for (int i = 1; i <= parameterCount; i++) // SQLite uses 1-based parameter indices
        {
            // Get the parameter name from the statement
            IntPtr paramNamePtr = sqlite3_bind_parameter_name(stmt, i);
            if (paramNamePtr == IntPtr.Zero)
            {
                // Unnamed parameter (like ?), skip it
                continue;
            }

            string fullParamName = Marshal.PtrToStringUTF8(paramNamePtr);
            if (string.IsNullOrEmpty(fullParamName) || fullParamName.Length < 2)
            {
                // Invalid parameter name, skip it
                continue;
            }

            // Remove the first character (prefix like :, @, $) to get the key name
            string keyName = fullParamName.Substring(1);

            // Look up the value in the dictionary
            object value = null;
            bool found = false;

            // Try different key variations
            if (namedArgs.Contains(keyName))
            {
                value = namedArgs[keyName];
                found = true;
            }
            else if (namedArgs.Contains(fullParamName))
            {
                value = namedArgs[fullParamName];
                found = true;
            }

            if (!found)
            {
                // throw an exception
                throw new ArgumentException($"Parameter '{fullParamName}' not found in the provided dictionary.");
            }

            // Bind the parameter value
            BindParameter(stmt, value, i);
        }
    }

    private int ExecuteNonQueryCore(string query, Action<IntPtr> bindParametersAction)
    {
        if (!IsOpen) throw new InvalidOperationException("Database is not open.");

        IntPtr stmt;
        IntPtr remainingQuery = IntPtr.Zero;
        string currentQuery = query;

        // Loop through all statements in the query
        while (!string.IsNullOrEmpty(currentQuery))
        {
            int result = prepare(_db, currentQuery, -1, out stmt, out remainingQuery);
            if (result != SQLITE_OK) throw new SQLiteException(GetLastErrorMessage(), result);

            // Bind parameters using the provided action
            bindParametersAction?.Invoke(stmt);

            // Ignore results if any (think insert ... returning ...)
            do
            {
                result = step(stmt);
            } while (result == SQLITE_ROW);

            if (result != SQLITE_DONE) throw new SQLiteException(GetLastErrorMessage(), result);

            result = finalize(stmt);
            if (result != SQLITE_OK) throw new SQLiteException(GetLastErrorMessage(), result);

            // Get the remaining query string for the next iteration
            if (remainingQuery != IntPtr.Zero)
            {
                currentQuery = Marshal.PtrToStringUni(remainingQuery);
                // Skip whitespace and check if there's more content
                currentQuery = currentQuery?.TrimStart();
            }
            else
            {
                currentQuery = null;
            }
        }

        return 0;
    }

    public int ExecuteNonQuery(string query, params object[] args)
    {
        int parameterIndex = 0;
        return ExecuteNonQueryCore(query, (stmt) =>
        {
            if (args != null && args.Length > parameterIndex)
            {
                parameterIndex += BindParameters(stmt, args, parameterIndex);
            }
        });
    }

    public int ExecuteNonQuery(string query, IDictionary namedArgs)
    {
        return ExecuteNonQueryCore(query, (stmt) =>
        {
            if (namedArgs != null && namedArgs.Count > 0)
            {
                BindParameters(stmt, namedArgs);
            }
        });
    }

    private DataSet ExecuteQueryCore(string query, Action<IntPtr> bindParametersAction)
    {
        IntPtr stmt;
        DataSet ds = new DataSet();
        IntPtr remainingQuery = IntPtr.Zero;
        string currentQuery = query;
        int tableIndex = 0;

        // Loop through all statements in the query
        while (!string.IsNullOrEmpty(currentQuery))
        {
            int result = prepare(_db, currentQuery, -1, out stmt, out remainingQuery);
            if (result != SQLITE_OK) throw new SQLiteException(GetLastErrorMessage(), result);

            // Bind parameters using the provided action
            bindParametersAction?.Invoke(stmt);

            int colCount = column_count(stmt);

            // Get the first row so that column name can be determined.
            result = step(stmt);
            if (result == SQLITE_ROW)
            {
                // Create a new DataTable for this SELECT statement
                DataTable dt = new DataTable();
                dt.TableName = String.Format("Table{0}", tableIndex);

                // Add corresponding columns to the data-table object.
                // NOTE: Since any column value can be NULL, we cannot infer fixed data
                //       types for the columns and therefore *must* use typeof(object).
                for (int c = 0; c < colCount; c++)
                {
                    dt.Columns.Add(Marshal.PtrToStringUni(column_name(stmt, c)), typeof(object));
                }

                // Fetch all rows and populate the DataTable instance with them.
                object[] rowData = new object[colCount];
                do
                {
                    for (int i = 0; i < colCount; i++)
                    {
                        // Note: The column types must be determined for each and every row,
                        //       given that NULL values may be present.
                        switch (column_type(stmt, i))
                        {
                            case SQLITE_INTEGER: // covers all integer types up to System.Int64
                                rowData[i] = column_int64(stmt, i);
                                break;
                            case SQLITE_FLOAT:
                                rowData[i] = column_double(stmt, i);
                                break;
                            case SQLITE_TEXT:
                                rowData[i] = Marshal.PtrToStringUni(column_text(stmt, i));
                                break;
                            case SQLITE_BLOB:
                                IntPtr ptr = column_blob(stmt, i);
                                int len = column_bytes(stmt, i);
                                byte[] arr = new byte[len];
                                Marshal.Copy(ptr, arr, 0, len);
                                rowData[i] = arr;
                                break;
                            case SQLITE_NULL:
                                rowData[i] = DBNull.Value;
                                break;
                            default:
                                throw new Exception(String.Format("DESIGN ERROR: Unexpected column-type ID: {0}", column_type(stmt, i)));
                        }
                    }
                    dt.Rows.Add(rowData);
                } while (step(stmt) == SQLITE_ROW);

                // Add the populated DataTable to the DataSet
                ds.Tables.Add(dt);
                tableIndex++;
            }
            else if (result == SQLITE_DONE)
            {
                // Either a query without results or a non-query statement - just continue to next statement
            }
            else
            {
                result = finalize(stmt);
                throw new SQLiteException(GetLastErrorMessage(), result);
            }

            result = finalize(stmt);
            if (result != SQLITE_OK) throw new SQLiteException(GetLastErrorMessage(), result);

            // Get the remaining query string for the next iteration
            if (remainingQuery != IntPtr.Zero)
            {
                currentQuery = Marshal.PtrToStringUni(remainingQuery);
                // Skip whitespace and check if there's more content
                currentQuery = currentQuery?.TrimStart();
            }
            else
            {
                currentQuery = null;
            }
        }

        // Return the DataSet instance containing all result tables.
        // In a PowerShell pipeline, the DataSet's .Tables collection can be enumerated,
        // or individual tables can be accessed by index or name.
        return ds;
    }

    public DataSet ExecuteQuery(string query, params object[] args)
    {
        int parameterIndex = 0;
        return ExecuteQueryCore(query, (stmt) =>
        {
            if (args != null && args.Length > parameterIndex)
            {
                parameterIndex += BindParameters(stmt, args, parameterIndex);
            }
        });
    }

    public DataSet ExecuteQuery(string query, IDictionary namedArgs)
    {
        return ExecuteQueryCore(query, (stmt) =>
        {
            if (namedArgs != null && namedArgs.Count > 0)
            {
                BindParameters(stmt, namedArgs);
            }
        });
    }

    public DataTable ExecuteSingleQuery(string query, params object[] args)
    {
        DataSet ds = ExecuteQuery(query, args);
        if (ds.Tables.Count > 0)
        {
            return ds.Tables[0];
        }
        return null;
    }

    public DataTable ExecuteSingleQuery(string query, IDictionary namedArgs)
    {
        DataSet ds = ExecuteQuery(query, namedArgs);
        if (ds.Tables.Count > 0)
        {
            return ds.Tables[0];
        }
        return null;
    }

    private TableSchema GetTableSchema(string tableName)
    {
        if (string.IsNullOrEmpty(tableName))
            throw new ArgumentException("Table name cannot be null or empty.", nameof(tableName));

        if (!IsOpen)
            throw new InvalidOperationException("Database is not open.");

        // Get the column information from the table schema
        string schemaQuery = $"PRAGMA table_info([{tableName}])";
        try
        {
            DataTable schemaTable = ExecuteSingleQuery(schemaQuery);

            if (schemaTable == null || schemaTable.Rows.Count == 0)
                throw new ArgumentException($"Table '{tableName}' does not exist or has no columns.");

            var schema = new TableSchema { TableName = tableName };

            // Extract column names and categorize them
            foreach (DataRow row in schemaTable.Rows)
            {
                string columnName = row["name"].ToString();
                string defaultValue = row["dflt_value"].ToString();
                bool isPrimaryKey = Convert.ToBoolean(row["pk"]);

                if (isPrimaryKey)
                {
                    schema.PrimaryKeyColumns.Add(columnName);
                    schema.AllColumns.Add(columnName);
                }
                else if (string.Equals(defaultValue, "CURRENT_TIMESTAMP", StringComparison.OrdinalIgnoreCase))
                {
                    schema.TimestampColumns.Add(columnName);

                    // Check if this is the designated update timestamp column
                    if (UpdateTimestampColumn != null && string.Equals(columnName, UpdateTimestampColumn, StringComparison.OrdinalIgnoreCase))
                    {
                        schema.UpdateTimestampColumn = columnName;
                        schema.HasUpdateTimestamp = true;
                        // Don't add update timestamp column to regular or all columns - it's handled specially
                    }
                    else
                    {
                        // Other timestamp columns are not included in insert/update operations
                    }
                }
                else
                {
                    schema.RegularColumns.Add(columnName);
                    schema.AllColumns.Add(columnName);
                }
            }

            return schema;
        }
        catch (SQLiteException)
        {
            throw new ArgumentException($"Table '{tableName}' does not exist or has no columns.");
        }
    }

    public string CreateInsertQuery(string tableName)
    {
        var schema = GetTableSchema(tableName);

        // Build the INSERT query using named parameters
        List<string> columnNames = new List<string>();
        List<string> parameterNames = new List<string>();

        foreach (string columnName in schema.RegularColumns)
        {
            columnNames.Add($"[{columnName}]");
            parameterNames.Add($":{columnName}");
        }

        string columns = string.Join(", ", columnNames);
        string parameters = string.Join(", ", parameterNames);
        string returning = string.Empty;
        if (schema.PrimaryKeyColumns.Count > 0)
        {
            returning = $" RETURNING {string.Join(", ", schema.PrimaryKeyColumns)}";
        }

        return $"INSERT INTO [{tableName}] ({columns}) VALUES ({parameters}){returning};";
    }

    public string CreateUpdateQuery(string tableName)
    {
        var schema = GetTableSchema(tableName);

        // Ensure there is at least one primary key column
        if (schema.PrimaryKeyColumns.Count == 0)
            throw new InvalidOperationException($"Table '{tableName}' has no primary key columns.");

        // Build the SET clause for non-primary key columns
        List<string> setClause = new List<string>();
        foreach (string columnName in schema.RegularColumns)
        {
            setClause.Add($"[{columnName}] = :{columnName}");
        }

        if (schema.HasUpdateTimestamp)
        {
            setClause.Add($"[{schema.UpdateTimestampColumn}] = CURRENT_TIMESTAMP");
        }

        // Build the WHERE clause for primary key columns
        List<string> whereClause = new List<string>();
        foreach (string columnName in schema.PrimaryKeyColumns)
        {
            whereClause.Add($"[{columnName}] = :{columnName}");
        }

        // Construct the final UPDATE query
        string setClauseStr = string.Join(", ", setClause);
        string whereClauseStr = string.Join(" AND ", whereClause);

        return $"UPDATE [{tableName}] SET {setClauseStr} WHERE {whereClauseStr}";
    }

    public string CreateUpsertQuery(string tableName)
    {
        var schema = GetTableSchema(tableName);

        // Ensure there is at least one primary key column
        if (schema.PrimaryKeyColumns.Count == 0)
            throw new InvalidOperationException($"Table '{tableName}' has no primary key columns.");

        // Build the INSERT portion (all columns)
        List<string> insertColumns = new List<string>();
        List<string> insertValues = new List<string>();
        foreach (string columnName in schema.AllColumns)
        {
            insertColumns.Add($"[{columnName}]");
            insertValues.Add($":{columnName}");
        }

        // Build the conflict target (primary key columns)
        List<string> conflictTarget = new List<string>();
        foreach (string columnName in schema.PrimaryKeyColumns)
        {
            conflictTarget.Add($"[{columnName}]");
        }

        // Build the UPDATE SET clause for non-primary key columns
        List<string> updateSetClause = new List<string>();
        foreach (string columnName in schema.RegularColumns)
        {
            updateSetClause.Add($"[{columnName}] = excluded.[{columnName}]");
        }
        if (schema.HasUpdateTimestamp)
        {
            updateSetClause.Add($"[{schema.UpdateTimestampColumn}] = CURRENT_TIMESTAMP");
        }

        // Construct the final UPSERT query
        string insertColumnsStr = string.Join(", ", insertColumns);
        string insertValuesStr = string.Join(", ", insertValues);
        string conflictTargetStr = string.Join(", ", conflictTarget);
        string updateSetClauseStr = string.Join(", ", updateSetClause);

        // If there are no non-primary key columns to update, use DO NOTHING
        string onConflictAction = updateSetClause.Count > 0
            ? $"DO UPDATE SET {updateSetClauseStr}"
            : "DO NOTHING";

        return $"INSERT INTO [{tableName}] ({insertColumnsStr}) VALUES ({insertValuesStr}) ON CONFLICT ({conflictTargetStr}) {onConflictAction}";
    }

}
