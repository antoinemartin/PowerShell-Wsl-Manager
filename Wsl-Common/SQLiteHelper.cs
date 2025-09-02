using System;
using System.Data;
using System.Collections.Generic;
using System.Runtime.InteropServices;

// cSpell: ignore winsqlite
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
    public class SqliteException : Exception
    {
        private int _nativeErrorCode;
        public int NativeErrorCode { get { return _nativeErrorCode; } set { _nativeErrorCode = value; } }
        public SqliteException(int code) : this(String.Format("SQLite API call failed with result code {0}.", code), code) { }
        public SqliteException(string message, int code) : base(message) { NativeErrorCode = code; }
    }

    private IntPtr _db;

    public bool IsOpen { get { return _db != IntPtr.Zero; } }

    private SQLiteHelper(IntPtr db) { _db = db; }

    public void Dispose()
    {
        Close();
    }

    public void Close()
    {
        if (!IsOpen) return;
        int result = close(_db);
        if (result != SQLITE_OK) throw new SqliteException(result);
        _db = IntPtr.Zero;
    }

    public static SQLiteHelper Open(string filename)
    {
        IntPtr db;
        int result = open(filename, out db);
        if (result != SQLITE_OK) throw new SqliteException(result);
        result = result_codes(db, 1); // report extended result codes by default.
        if (result != SQLITE_OK) throw new SqliteException(result);
        return new SQLiteHelper(db);
    }

    private static int BindParameters(IntPtr stmt, object[] args, int startIndex)
    {
        int parameterCount = sqlite3_bind_parameter_count(stmt);
        int consumed = 0;

        for (int i = 0; i < parameterCount && (startIndex + consumed) < args.Length; i++)
        {
            object arg = args[startIndex + consumed];
            int sqliteIndex = i + 1; // SQLite uses 1-based parameter indices.
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
            if (result != SQLITE_OK) throw new SqliteException(result);
            consumed++;
        }

        return consumed;
    }

    public int ExecuteNonQuery(string query, params object[] args)
    {
        if (!IsOpen) throw new InvalidOperationException("Database is not open.");

        IntPtr stmt;
        IntPtr remainingQuery = IntPtr.Zero;
        string currentQuery = query;
        int parameterIndex = 0;

        // Loop through all statements in the query
        while (!string.IsNullOrEmpty(currentQuery))
        {
            int result = prepare(_db, currentQuery, -1, out stmt, out remainingQuery);
            if (result != SQLITE_OK) throw new SqliteException(result);

            // Bind parameters starting from the current parameter index
            if (args != null && args.Length > parameterIndex)
            {
                parameterIndex += BindParameters(stmt, args, parameterIndex);
            }

            result = step(stmt);
            if (result != SQLITE_DONE) throw new SqliteException(result);

            result = finalize(stmt);
            if (result != SQLITE_OK) throw new SqliteException(result);

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

    public DataSet ExecuteQuery(string query, params object[] args)
    {
        IntPtr stmt;
        DataSet ds = new DataSet();
        IntPtr remainingQuery = IntPtr.Zero;
        string currentQuery = query;
        int parameterIndex = 0;
        int tableIndex = 0;

        // Loop through all statements in the query
        while (!string.IsNullOrEmpty(currentQuery))
        {
            int result = prepare(_db, currentQuery, -1, out stmt, out remainingQuery);
            if (result != SQLITE_OK) throw new SqliteException(result);

            // Bind parameters starting from the current parameter index
            if (args != null && args.Length > parameterIndex)
            {
                parameterIndex += BindParameters(stmt, args, parameterIndex);
            }

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
                throw new SqliteException(result);
            }

            result = finalize(stmt);
            if (result != SQLITE_OK) throw new SqliteException(result);

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
}
