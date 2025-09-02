[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '')]
Param()

BeforeAll {
    . (Join-Path $PSScriptRoot ".." "Wsl-Common" "SQLite.ps1")
}

Describe "SQLite" {
    It "Can create an in-memory database, create a table, insert a row, and query it back" {
        $db = [SQLiteHelper]::Open(":memory:")
        try {
            $null = $db.ExecuteNonQuery("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT);")
            $null = $db.ExecuteNonQuery("INSERT INTO test (name) VALUES (?);", @("Alice"))
            $result = $db.ExecuteQuery("SELECT id, name FROM test;")
            $result.Tables.Count | Should -Be 1
            $table = $result.Tables[0]
            $table.Rows.Count | Should -Be 1
            $table.Rows[0].id | Should -Be 1
            $table.Rows[0].name | Should -Be "Alice"
        } finally {
            $db.Close()
        }
    }

    It "Handles SQL errors gracefully" {
        $db = [SQLiteHelper]::Open(":memory:")
        try {
            { $null = $db.ExecuteNonQuery("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT);") } | Should -Not -Throw
            { $null = $db.ExecuteNonQuery("INSERT INTO non_existing_table (name) VALUES (?);", @("Bob")) } | Should -Throw
            { $null = $db.ExecuteNonQuery("INSERT INTO test (name) VALUES (?);", @("Bob")) } | Should -Not -Throw
            { $null = $db.ExecuteNonQuery("INSERT INTO test (id, name) VALUES (?, ?);", @(1, "Bob")) } | Should -Throw
            { $null = $db.ExecuteNonQuery("INSERT INTO test (id, name) VALUES (?, ?);", @(2, "Alice")) } | Should -Not -Throw
            $result = $db.ExecuteQuery("SELECT count(*) as count FROM test;")
            $result.Tables.Count | Should -Be 1
            $table = $result.Tables[0]
            $table.Rows.Count | Should -Be 1
            $table.Rows[0].count | Should -Be 2
            $result = $db.ExecuteQuery("SELECT * FROM test")
            $result.Tables.Count | Should -Be 1
            $table = $result.Tables[0]
            $table.Rows.Count | Should -Be 2
            $table.Rows[0].id | Should -Be 1
            $table.Rows[0].name | Should -Be "Bob"
            $table.Rows[1].id | Should -Be 2
            $table.Rows[1].name | Should -Be "Alice"
        } finally {
            $db.Close()
        }
    }

    It "Should support multiple creation queries" {
        $db = [SQLiteHelper]::Open(":memory:")
        try {
            $null = $db.ExecuteNonQuery("CREATE TABLE test (id INTEGER); INSERT INTO test VALUES (1); INSERT INTO test VALUES (2);")
            $result = $db.ExecuteQuery("SELECT * from test;")
            $result.Tables.Count | Should -Be 1
            $table = $result.Tables[0]
            $table.Rows.Count | Should -Be 2
            $table.Rows[0].id | Should -Be 1
            $table.Rows[1].id | Should -Be 2
        } finally {
            $db.Close()
        }
    }

    It "Should span parameters on multiple queries" {
        $db = [SQLiteHelper]::Open(":memory:")
        try {
            $null = $db.ExecuteNonQuery("CREATE TABLE test (id INTEGER, name TEXT); INSERT INTO test (id, name) VALUES (?, ?); INSERT INTO test (id, name) VALUES (?, ?);", @(1, "Alice", 2, "Bob"))
            $result = $db.ExecuteQuery("SELECT * from test;")
            $result.Tables.Count | Should -Be 1
            $table = $result.Tables[0]
            $table.Rows.Count | Should -Be 2
            $table.Rows[0].id | Should -Be 1
            $table.Rows[0].name | Should -Be "Alice"
            $table.Rows[1].id | Should -Be 2
            $table.Rows[1].name | Should -Be "Bob"
        } finally {
            $db.Close()
        }
    }

    It "Should return multiple DataTables for multiple SELECT statements" {
        $db = [SQLiteHelper]::Open(":memory:")
        try {
            $null = $db.ExecuteNonQuery("CREATE TABLE users (id INTEGER, name TEXT); CREATE TABLE orders (id INTEGER, user_id INTEGER, product TEXT);")
            $null = $db.ExecuteNonQuery("INSERT INTO users VALUES (1, 'Alice'); INSERT INTO users VALUES (2, 'Bob');")
            $null = $db.ExecuteNonQuery("INSERT INTO orders VALUES (101, 1, 'Laptop'); INSERT INTO orders VALUES (102, 2, 'Mouse');")

            $result = $db.ExecuteQuery("SELECT * FROM users; SELECT * FROM orders;")

            # Should have 2 tables in the DataSet
            $result.Tables.Count | Should -Be 2

            # First table should contain users
            $table = $result.Tables[0]
            $table.Rows.Count | Should -Be 2
            $table.Rows[0].id | Should -Be 1
            $table.Rows[0].name | Should -Be "Alice"
            $table.Rows[1].id | Should -Be 2
            $table.Rows[1].name | Should -Be "Bob"

            # Second table should contain orders
            $table = $result.Tables[1]
            $table.Rows.Count | Should -Be 2
            $table.Rows[0].id | Should -Be 101
            $table.Rows[0].user_id | Should -Be 1
            $table.Rows[0].product | Should -Be "Laptop"
            $table.Rows[1].id | Should -Be 102
            $table.Rows[1].user_id | Should -Be 2
            $table.Rows[1].product | Should -Be "Mouse"

            # Tables should have proper names
            $table = $result.Tables[0]
            $table.TableName | Should -Be "Table0"
            $table = $result.Tables[1]
            $table.TableName | Should -Be "Table1"

            $ds = $db.ExecuteQuery("SELECT * from users where name = ?;select * from orders where user_id = ?;", @("Alice", 1))
            $ds.Tables.Count | Should -Be 2
            $rs = $ds.Tables[0]
            $rs.Rows.Count | Should -Be 1
            $rs.Rows[0].id | Should -Be 1
            $rs.Rows[0].name | Should -Be "Alice"

            $rs = $ds.Tables[1]
            $rs.Rows.Count | Should -Be 1
            $rs.Rows[0].id | Should -Be 101
            $rs.Rows[0].user_id | Should -Be 1
            $rs.Rows[0].product | Should -Be "Laptop"
        } finally {
            $db.Close()
        }
    }
}
