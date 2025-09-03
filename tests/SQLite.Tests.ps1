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

    It "ExecuteSingleQuery should return first table from result set" {
        $db = [SQLiteHelper]::Open(":memory:")
        try {
            $null = $db.ExecuteNonQuery("CREATE TABLE test (id INTEGER, name TEXT);")
            $null = $db.ExecuteNonQuery("INSERT INTO test VALUES (1, 'Alice'), (2, 'Bob');")

            # Test with single query
            $table = $db.ExecuteSingleQuery("SELECT * FROM test;")
            $table | Should -Not -BeNullOrEmpty
            $table.Rows.Count | Should -Be 2
            $table.Rows[0].id | Should -Be 1
            $table.Rows[0].name | Should -Be "Alice"
            $table.Rows[1].id | Should -Be 2
            $table.Rows[1].name | Should -Be "Bob"

            # Test with parameters
            $table = $db.ExecuteSingleQuery("SELECT * FROM test WHERE name = ?;", @("Alice"))
            $table | Should -Not -BeNullOrEmpty
            $table.Rows.Count | Should -Be 1
            $table.Rows[0].id | Should -Be 1
            $table.Rows[0].name | Should -Be "Alice"

            # Test with no results
            $table = $db.ExecuteSingleQuery("SELECT * FROM test WHERE name = ?;", @("Charlie"))
            $table | Should -BeNullOrEmpty

            # Test with non-query statement
            $table = $db.ExecuteSingleQuery("UPDATE test SET name = 'Updated' WHERE id = 1;")
            $table | Should -BeNullOrEmpty
        } finally {
            $db.Close()
        }
    }

    It "CreateInsertQuery should generate correct INSERT statements" {
        $db = [SQLiteHelper]::Open(":memory:")
        try {
            # Create a test table with various column types
            $null = $db.ExecuteNonQuery("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL, email TEXT, age INTEGER);")

            # Test basic functionality
            $insertQuery = $db.CreateInsertQuery("users")
            $insertQuery | Should -Be "INSERT INTO [users] ([id], [name], [email], [age]) VALUES (?, ?, ?, ?)"

            # Test that generated query works for actual inserts
            $null = $db.ExecuteNonQuery($insertQuery, @(1, "Alice", "alice@example.com", 25))
            $result = $db.ExecuteSingleQuery("SELECT * FROM users WHERE id = 1;")
            $result.Rows.Count | Should -Be 1
            $result.Rows[0].name | Should -Be "Alice"
            $result.Rows[0].email | Should -Be "alice@example.com"
            $result.Rows[0].age | Should -Be 25

            # Test with table name that has reserved words
            $null = $db.ExecuteNonQuery("CREATE TABLE [order] ([select] INTEGER, [from] TEXT);")
            $insertQuery = $db.CreateInsertQuery("order")
            $insertQuery | Should -Be "INSERT INTO [order] ([select], [from]) VALUES (?, ?)"

            # Test that generated query works with reserved words
            $null = $db.ExecuteNonQuery($insertQuery, @(42, "test"))
            $result = $db.ExecuteSingleQuery("SELECT * FROM [order];")
            $result.Rows.Count | Should -Be 1
            $result.Rows[0]."select" | Should -Be 42
            $result.Rows[0]."from" | Should -Be "test"
        } finally {
            $db.Close()
        }
    }

    It "CreateInsertQuery should handle error conditions" {
        $db = [SQLiteHelper]::Open(":memory:")
        try {
            # Test with non-existent table
            { $db.CreateInsertQuery("non_existent_table") } | Should -Throw

            # Test with null/empty table name
            { $db.CreateInsertQuery("") } | Should -Throw
            { $db.CreateInsertQuery($null) } | Should -Throw
        } finally {
            $db.Close()
        }

        # Test with closed database
        { $db.CreateInsertQuery("any_table") } | Should -Throw
    }

    It "CreateUpdateQuery should generate correct UPDATE statements" {
        $db = [SQLiteHelper]::Open(":memory:")
        try {
            # Create a test table with primary key
            $null = $db.ExecuteNonQuery("CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT, price REAL, category TEXT);")

            # Test basic functionality
            $updateQuery = $db.CreateUpdateQuery("products")
            $updateQuery | Should -Be "UPDATE [products] SET [name] = :name, [price] = :price, [category] = :category WHERE [id] = :id"

            # Test that generated query works for actual updates
            $null = $db.ExecuteNonQuery("INSERT INTO products VALUES (1, 'Laptop', 999.99, 'Electronics');")

            $updateParams = @{
                "id" = 1
                "name" = "Gaming Laptop"
                "price" = 1299.99
                "category" = "Gaming"
            }
            $null = $db.ExecuteNonQuery($updateQuery, $updateParams)

            $result = $db.ExecuteSingleQuery("SELECT * FROM products WHERE id = 1;")
            $result.Rows.Count | Should -Be 1
            $result.Rows[0].name | Should -Be "Gaming Laptop"
            $result.Rows[0].price | Should -Be 1299.99
            $result.Rows[0].category | Should -Be "Gaming"

            # Test with composite primary key
            $null = $db.ExecuteNonQuery("CREATE TABLE user_roles (user_id INTEGER, role_id INTEGER, assigned_date TEXT, PRIMARY KEY (user_id, role_id));")
            $updateQuery = $db.CreateUpdateQuery("user_roles")
            $updateQuery | Should -Be "UPDATE [user_roles] SET [assigned_date] = :assigned_date WHERE [user_id] = :user_id AND [role_id] = :role_id"

            # Test that composite key query works
            $null = $db.ExecuteNonQuery("INSERT INTO user_roles VALUES (1, 100, '2024-01-01');")
            $updateParams = @{
                "user_id" = 1
                "role_id" = 100
                "assigned_date" = "2024-01-15"
            }
            $null = $db.ExecuteNonQuery($updateQuery, $updateParams)

            $result = $db.ExecuteSingleQuery("SELECT * FROM user_roles WHERE user_id = 1 AND role_id = 100;")
            $result.Rows.Count | Should -Be 1
            $result.Rows[0].assigned_date | Should -Be "2024-01-15"

            # Test with table name that has reserved words
            $null = $db.ExecuteNonQuery("CREATE TABLE [order] ([select] INTEGER PRIMARY KEY, [from] TEXT, [where] TEXT);")
            $updateQuery = $db.CreateUpdateQuery("order")
            $updateQuery | Should -Be "UPDATE [order] SET [from] = :from, [where] = :where WHERE [select] = :select"

            # Test that reserved words query works
            $null = $db.ExecuteNonQuery("INSERT INTO [order] VALUES (42, 'source', 'destination');")
            $updateParams = @{
                "select" = 42
                "from" = "new_source"
                "where" = "new_destination"
            }
            $null = $db.ExecuteNonQuery($updateQuery, $updateParams)

            $result = $db.ExecuteSingleQuery("SELECT * FROM [order] WHERE [select] = 42;")
            $result.Rows.Count | Should -Be 1
            $result.Rows[0]."from" | Should -Be "new_source"
            $result.Rows[0]."where" | Should -Be "new_destination"
        } finally {
            $db.Close()
        }
    }

    It "CreateUpdateQuery should handle error conditions" {
        $db = [SQLiteHelper]::Open(":memory:")
        try {
            # Test with non-existent table
            { $db.CreateUpdateQuery("non_existent_table") } | Should -Throw

            # Test with null/empty table name
            { $db.CreateUpdateQuery("") } | Should -Throw
            { $db.CreateUpdateQuery($null) } | Should -Throw

            # Test with table that has no primary key
            $null = $db.ExecuteNonQuery("CREATE TABLE no_pk_table (name TEXT, value INTEGER);")
            { $db.CreateUpdateQuery("no_pk_table") } | Should -Throw -ExpectedMessage "*has no primary key columns*"
        } finally {
            $db.Close()
        }

        # Test with closed database
        { $db.CreateUpdateQuery("any_table") } | Should -Throw
    }

    It "CreateUpsertQuery should generate correct UPSERT statements" {
        $db = [SQLiteHelper]::Open(":memory:")
        try {
            # Create a test table with primary key
            $null = $db.ExecuteNonQuery("CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT, price REAL, category TEXT);")

            # Test basic functionality
            $upsertQuery = $db.CreateUpsertQuery("products")
            $upsertQuery | Should -Be "INSERT INTO [products] ([id], [name], [price], [category]) VALUES (:id, :name, :price, :category) ON CONFLICT ([id]) DO UPDATE SET [name] = excluded.[name], [price] = excluded.[price], [category] = excluded.[category]"

            # Test that generated query works for insert (new record)
            $upsertParams = @{
                "id" = 1
                "name" = "Laptop"
                "price" = 999.99
                "category" = "Electronics"
            }
            $null = $db.ExecuteNonQuery($upsertQuery, $upsertParams)

            $result = $db.ExecuteSingleQuery("SELECT * FROM products WHERE id = 1;")
            $result.Rows.Count | Should -Be 1
            $result.Rows[0].name | Should -Be "Laptop"
            $result.Rows[0].price | Should -Be 999.99
            $result.Rows[0].category | Should -Be "Electronics"

            # Test that generated query works for update (existing record)
            $upsertParams = @{
                "id" = 1
                "name" = "Gaming Laptop"
                "price" = 1299.99
                "category" = "Gaming"
            }
            $null = $db.ExecuteNonQuery($upsertQuery, $upsertParams)

            $result = $db.ExecuteSingleQuery("SELECT * FROM products WHERE id = 1;")
            $result.Rows.Count | Should -Be 1
            $result.Rows[0].name | Should -Be "Gaming Laptop"
            $result.Rows[0].price | Should -Be 1299.99
            $result.Rows[0].category | Should -Be "Gaming"

            # Verify only one record exists (no duplicate)
            $result = $db.ExecuteSingleQuery("SELECT COUNT(*) as count FROM products;")
            $result.Rows[0].count | Should -Be 1

            # Test with composite primary key
            $null = $db.ExecuteNonQuery("CREATE TABLE user_roles (user_id INTEGER, role_id INTEGER, assigned_date TEXT, notes TEXT, PRIMARY KEY (user_id, role_id));")
            $upsertQuery = $db.CreateUpsertQuery("user_roles")
            $upsertQuery | Should -Be "INSERT INTO [user_roles] ([user_id], [role_id], [assigned_date], [notes]) VALUES (:user_id, :role_id, :assigned_date, :notes) ON CONFLICT ([user_id], [role_id]) DO UPDATE SET [assigned_date] = excluded.[assigned_date], [notes] = excluded.[notes]"

            # Test insert with composite key
            $upsertParams = @{
                "user_id" = 1
                "role_id" = 100
                "assigned_date" = "2024-01-01"
                "notes" = "Initial assignment"
            }
            $null = $db.ExecuteNonQuery($upsertQuery, $upsertParams)

            $result = $db.ExecuteSingleQuery("SELECT * FROM user_roles WHERE user_id = 1 AND role_id = 100;")
            $result.Rows.Count | Should -Be 1
            $result.Rows[0].assigned_date | Should -Be "2024-01-01"
            $result.Rows[0].notes | Should -Be "Initial assignment"

            # Test update with composite key
            $upsertParams = @{
                "user_id" = 1
                "role_id" = 100
                "assigned_date" = "2024-01-15"
                "notes" = "Updated assignment"
            }
            $null = $db.ExecuteNonQuery($upsertQuery, $upsertParams)

            $result = $db.ExecuteSingleQuery("SELECT * FROM user_roles WHERE user_id = 1 AND role_id = 100;")
            $result.Rows.Count | Should -Be 1
            $result.Rows[0].assigned_date | Should -Be "2024-01-15"
            $result.Rows[0].notes | Should -Be "Updated assignment"

            # Test with table that has only primary key columns (should use DO NOTHING)
            $null = $db.ExecuteNonQuery("CREATE TABLE lookup_table (code INTEGER PRIMARY KEY);")
            $upsertQuery = $db.CreateUpsertQuery("lookup_table")
            $upsertQuery | Should -Be "INSERT INTO [lookup_table] ([code]) VALUES (:code) ON CONFLICT ([code]) DO NOTHING"

            # Test that DO NOTHING query works
            $upsertParams = @{ "code" = 42 }
            $null = $db.ExecuteNonQuery($upsertQuery, $upsertParams)
            $null = $db.ExecuteNonQuery($upsertQuery, $upsertParams) # Should not cause error or duplicate

            $result = $db.ExecuteSingleQuery("SELECT COUNT(*) as count FROM lookup_table WHERE code = 42;")
            $result.Rows[0].count | Should -Be 1

            # Test with table name that has reserved words
            $null = $db.ExecuteNonQuery("CREATE TABLE [order] ([select] INTEGER PRIMARY KEY, [from] TEXT, [where] TEXT);")
            $upsertQuery = $db.CreateUpsertQuery("order")
            $upsertQuery | Should -Be "INSERT INTO [order] ([select], [from], [where]) VALUES (:select, :from, :where) ON CONFLICT ([select]) DO UPDATE SET [from] = excluded.[from], [where] = excluded.[where]"

            # Test that reserved words query works for insert
            $upsertParams = @{
                "select" = 42
                "from" = "source"
                "where" = "destination"
            }
            $null = $db.ExecuteNonQuery($upsertQuery, $upsertParams)

            $result = $db.ExecuteSingleQuery("SELECT * FROM [order] WHERE [select] = 42;")
            $result.Rows.Count | Should -Be 1
            $result.Rows[0]."from" | Should -Be "source"
            $result.Rows[0]."where" | Should -Be "destination"

            # Test that reserved words query works for update
            $upsertParams = @{
                "select" = 42
                "from" = "new_source"
                "where" = "new_destination"
            }
            $null = $db.ExecuteNonQuery($upsertQuery, $upsertParams)

            $result = $db.ExecuteSingleQuery("SELECT * FROM [order] WHERE [select] = 42;")
            $result.Rows.Count | Should -Be 1
            $result.Rows[0]."from" | Should -Be "new_source"
            $result.Rows[0]."where" | Should -Be "new_destination"
        } finally {
            $db.Close()
        }
    }

    It "CreateUpsertQuery should handle error conditions" {
        $db = [SQLiteHelper]::Open(":memory:")
        try {
            # Test with non-existent table
            { $db.CreateUpsertQuery("non_existent_table") } | Should -Throw

            # Test with null/empty table name
            { $db.CreateUpsertQuery("") } | Should -Throw
            { $db.CreateUpsertQuery($null) } | Should -Throw

            # Test with table that has no primary key
            $null = $db.ExecuteNonQuery("CREATE TABLE no_pk_table (name TEXT, value INTEGER);")
            { $db.CreateUpsertQuery("no_pk_table") } | Should -Throw -ExpectedMessage "*has no primary key columns*"
        } finally {
            $db.Close()
        }

        # Test with closed database
        { $db.CreateUpsertQuery("any_table") } | Should -Throw
    }

    Context "Named Parameters" {
        It "Should support ExecuteNonQuery with named parameters using colon prefix" {
            $db = [SQLiteHelper]::Open(":memory:")
            try {
                $null = $db.ExecuteNonQuery("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT, age INTEGER);")

                $namedParams = @{
                    "name" = "Alice"
                    "age" = 30
                }

                $null = $db.ExecuteNonQuery("INSERT INTO test (name, age) VALUES (:name, :age);", $namedParams)

                $result = $db.ExecuteQuery("SELECT id, name, age FROM test;")
                $result.Tables.Count | Should -Be 1
                $table = $result.Tables[0]
                $table.Rows.Count | Should -Be 1
                $table.Rows[0].id | Should -Be 1
                $table.Rows[0].name | Should -Be "Alice"
                $table.Rows[0].age | Should -Be 30
            } finally {
                $db.Close()
            }
        }

        It "Should support ExecuteNonQuery with named parameters using @ prefix" {
            $db = [SQLiteHelper]::Open(":memory:")
            try {
                $null = $db.ExecuteNonQuery("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT, email TEXT);")

                $namedParams = @{
                    "name" = "Bob"
                    "email" = "bob@example.com"
                }

                $null = $db.ExecuteNonQuery("INSERT INTO test (name, email) VALUES (@name, @email);", $namedParams)

                $result = $db.ExecuteQuery("SELECT * FROM test;")
                $table = $result.Tables[0]
                $table.Rows.Count | Should -Be 1
                $table.Rows[0].name | Should -Be "Bob"
                $table.Rows[0].email | Should -Be "bob@example.com"
            } finally {
                $db.Close()
            }
        }

        It "Should support ExecuteNonQuery with named parameters using $ prefix" {
            $db = [SQLiteHelper]::Open(":memory:")
            try {
                $null = $db.ExecuteNonQuery("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT, score REAL);")

                $namedParams = @{
                    "name" = "Charlie"
                    "score" = 95.5
                }

                $null = $db.ExecuteNonQuery("INSERT INTO test (name, score) VALUES (`$name, `$score);", $namedParams)

                $result = $db.ExecuteQuery("SELECT * FROM test;")
                $table = $result.Tables[0]
                $table.Rows.Count | Should -Be 1
                $table.Rows[0].name | Should -Be "Charlie"
                $table.Rows[0].score | Should -Be 95.5
            } finally {
                $db.Close()
            }
        }

        It "Should handle various data types with named parameters" {
            $db = [SQLiteHelper]::Open(":memory:")
            try {
                $null = $db.ExecuteNonQuery("CREATE TABLE test (id INTEGER, name TEXT, score REAL, data BLOB, created_date TEXT, is_active INTEGER);")

                $blobData = [byte[]]@(1, 2, 3, 4, 5)
                $namedParams = @{
                    "id" = [Int64]123
                    "name" = "Test User"
                    "score" = 87.5
                    "data" = $blobData
                    "created_date" = "2024-01-01"
                    "is_active" = $null
                }

                $null = $db.ExecuteNonQuery("INSERT INTO test (id, name, score, data, created_date, is_active) VALUES (:id, :name, :score, :data, :created_date, :is_active);", $namedParams)

                $result = $db.ExecuteQuery("SELECT * FROM test;")
                $table = $result.Tables[0]
                $table.Rows.Count | Should -Be 1
                $table.Rows[0].id | Should -Be 123
                $table.Rows[0].name | Should -Be "Test User"
                $table.Rows[0].score | Should -Be 87.5
                $table.Rows[0].data | Should -Be $blobData
                $table.Rows[0].created_date | Should -Be "2024-01-01"
                $table.Rows[0].is_active | Should -Be ([System.DBNull]::Value)
            } finally {
                $db.Close()
            }
        }

        It "Should support ExecuteQuery with named parameters" {
            $db = [SQLiteHelper]::Open(":memory:")
            try {
                $null = $db.ExecuteNonQuery("CREATE TABLE users (id INTEGER, name TEXT, age INTEGER, city TEXT);")
                $null = $db.ExecuteNonQuery("INSERT INTO users VALUES (1, 'Alice', 25, 'New York'), (2, 'Bob', 30, 'Boston'), (3, 'Charlie', 25, 'New York');")

                $namedParams = @{
                    "min_age" = 25
                    "city" = "New York"
                }

                $result = $db.ExecuteQuery("SELECT * FROM users WHERE age >= :min_age AND city = :city ORDER BY name;", $namedParams)
                $table = $result.Tables[0]
                $table.Rows.Count | Should -Be 2
                $table.Rows[0].name | Should -Be "Alice"
                $table.Rows[0].city | Should -Be "New York"
                $table.Rows[1].name | Should -Be "Charlie"
                $table.Rows[1].city | Should -Be "New York"
            } finally {
                $db.Close()
            }
        }

        It "Should support ExecuteSingleQuery with named parameters" {
            $db = [SQLiteHelper]::Open(":memory:")
            try {
                $null = $db.ExecuteNonQuery("CREATE TABLE products (id INTEGER, name TEXT, price REAL, category TEXT);")
                $null = $db.ExecuteNonQuery("INSERT INTO products VALUES (1, 'Laptop', 999.99, 'Electronics'), (2, 'Book', 29.99, 'Education');")

                $namedParams = @{
                    "category" = "Electronics"
                }

                $table = $db.ExecuteSingleQuery("SELECT * FROM products WHERE category = :category;", $namedParams)
                $table | Should -Not -BeNullOrEmpty
                $table.Rows.Count | Should -Be 1
                $table.Rows[0].name | Should -Be "Laptop"
                $table.Rows[0].price | Should -Be 999.99
                $table.Rows[0].category | Should -Be "Electronics"
            } finally {
                $db.Close()
            }
        }

        It "Should handle multiple statements with named parameters" {
            $db = [SQLiteHelper]::Open(":memory:")
            try {
                $null = $db.ExecuteNonQuery("CREATE TABLE test (id INTEGER, name TEXT);")

                $namedParams = @{
                    "id1" = 1
                    "name1" = "Alice"
                    "id2" = 2
                    "name2" = "Bob"
                }

                # Note: SQLite named parameters are per-statement, so each statement uses its own parameters
                $null = $db.ExecuteNonQuery("INSERT INTO test (id, name) VALUES (:id1, :name1); INSERT INTO test (id, name) VALUES (:id2, :name2);", $namedParams)

                $result = $db.ExecuteQuery("SELECT * FROM test ORDER BY id;")
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

        It "Should handle empty named parameters dictionary" {
            $db = [SQLiteHelper]::Open(":memory:")
            try {
                $null = $db.ExecuteNonQuery("CREATE TABLE test (id INTEGER);")

                $emptyParams = @{}

                # Query without parameters should work with empty dictionary
                $null = $db.ExecuteNonQuery("INSERT INTO test (id) VALUES (42);", $emptyParams)

                $result = $db.ExecuteQuery("SELECT * FROM test;", $emptyParams)
                $table = $result.Tables[0]
                $table.Rows.Count | Should -Be 1
                $table.Rows[0].id | Should -Be 42
            } finally {
                $db.Close()
            }
        }

        It "Should handle null named parameters dictionary" {
            $db = [SQLiteHelper]::Open(":memory:")
            try {
                $null = $db.ExecuteNonQuery("CREATE TABLE test (id INTEGER);")

                # Query without parameters should work with null dictionary
                $null = $db.ExecuteNonQuery("INSERT INTO test (id) VALUES (99);", $null)

                $result = $db.ExecuteQuery("SELECT * FROM test;", $null)
                $table = $result.Tables[0]
                $table.Rows.Count | Should -Be 1
                $table.Rows[0].id | Should -Be 99
            } finally {
                $db.Close()
            }
        }

        It "Should throw error for missing named parameter" {
            $db = [SQLiteHelper]::Open(":memory:")
            try {
                $null = $db.ExecuteNonQuery("CREATE TABLE test (id INTEGER, name TEXT);")

                $incompleteParams = @{
                    "name" = "Alice"
                    # Missing "id" parameter
                }

                { $db.ExecuteNonQuery("INSERT INTO test (id, name) VALUES (:id, :name);", $incompleteParams) } | Should -Throw -ExpectedMessage "*Parameter ':id' not found*"
            } finally {
                $db.Close()
            }
        }

        It "Should throw error for unsupported parameter type" {
            $db = [SQLiteHelper]::Open(":memory:")
            try {
                $null = $db.ExecuteNonQuery("CREATE TABLE test (id INTEGER);")

                $invalidParams = @{
                    "id" = New-Object System.Collections.ArrayList
                }

                { $db.ExecuteNonQuery("INSERT INTO test (id) VALUES (:id);", $invalidParams) } | Should -Throw -ExpectedMessage "*Cannot bind parameter*"
            } finally {
                $db.Close()
            }
        }

        It "Should work with multiple result sets and named parameters" {
            $db = [SQLiteHelper]::Open(":memory:")
            try {
                $null = $db.ExecuteNonQuery("CREATE TABLE users (id INTEGER, name TEXT); CREATE TABLE orders (id INTEGER, user_name TEXT, product TEXT);")
                $null = $db.ExecuteNonQuery("INSERT INTO users VALUES (1, 'Alice'), (2, 'Bob'); INSERT INTO orders VALUES (101, 'Alice', 'Laptop'), (102, 'Bob', 'Mouse');")

                $namedParams = @{
                    "user_name" = "Alice"
                }

                $result = $db.ExecuteQuery("SELECT * FROM users WHERE name = :user_name; SELECT * FROM orders WHERE user_name = :user_name;", $namedParams)

                # Should have 2 tables in the DataSet
                $result.Tables.Count | Should -Be 2

                # First table should contain the user
                $usersTable = $result.Tables[0]
                $usersTable.Rows.Count | Should -Be 1
                $usersTable.Rows[0].name | Should -Be "Alice"

                # Second table should contain the orders
                $ordersTable = $result.Tables[1]
                $ordersTable.Rows.Count | Should -Be 1
                $ordersTable.Rows[0].user_name | Should -Be "Alice"
                $ordersTable.Rows[0].product | Should -Be "Laptop"
            } finally {
                $db.Close()
            }
        }

        It "Should handle parameter names with different prefixes in same statement" {
            $db = [SQLiteHelper]::Open(":memory:")
            try {
                $null = $db.ExecuteNonQuery("CREATE TABLE test (id INTEGER, name TEXT, email TEXT);")

                $namedParams = @{
                    "id" = 1        # Already has colon prefix
                    "name" = "Alice"  # Will get colon prefix added
                    "email" = "alice@example.com"  # Has @ prefix, should work
                }

                $null = $db.ExecuteNonQuery("INSERT INTO test (id, name, email) VALUES (`$id, :name, @email);", $namedParams)

                $result = $db.ExecuteQuery("SELECT * FROM test;")
                $table = $result.Tables[0]
                $table.Rows.Count | Should -Be 1
                $table.Rows[0].id | Should -Be 1
                $table.Rows[0].name | Should -Be "Alice"
                $table.Rows[0].email | Should -Be "alice@example.com"
            } finally {
                $db.Close()
            }
        }
    }
}
