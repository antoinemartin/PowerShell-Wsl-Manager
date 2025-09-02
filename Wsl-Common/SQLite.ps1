# cSpell: ignore winsqlite libsqlite dylib
# Compile helper type [SqliteHelper], which is a thin layer on top of the C/C++
# SQLite API.
# Gratefully adapted from https://stackoverflow.com/a/76488520/45375
# Determine the platform-appropriate name of the native SQLite library.
# Note: Tested on Windows and Linux.
# Compile the code.
# NOTE:
#   * Re -ReferencedAssemblies:
#      * System.Data.Common, System.Collections are needed for PS Core, System.Xml is needed for WinPS.
#   * For the sake of WinPS compatibility:
#     * The code below uses (a) legacy property-definition syntax and (b) legacy dictionary initializer syntax.
#     * The *16() variants of the SQLite functions are used so that .NET (UTF-16LE) strings can be used / converted via
#       Marshal.PtrToStringUni().
#       Behind the scenes, SQLite still translates to and from UTF-8, but not having to deal with that on the .NET
#       side makes things easier, given that only .NET (Core) supports Marshal.PtrToStringUTF8()

$TypeDefinition = Get-Content (Join-Path -Path $PSScriptRoot -ChildPath 'SQLiteHelper.cs') -Raw
if ($IsLinux) {
    $TypeDefinition = $TypeDefinition -replace 'winsqlite3.dll', 'libsqlite3.so.0'
} elseif ($IsMacOS) {
    $TypeDefinition = $TypeDefinition -replace 'winsqlite3.dll', 'libsqlite3.dylib'
}

Add-Type -ReferencedAssemblies System.Collections, System.Data, System.Data.Common, System.Xml, System.ComponentModel.TypeConverter -Language CSharp -TypeDefinition $TypeDefinition
