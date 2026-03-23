# Rename or Move Remote SFTP Resources

Renames a file or directory on the SFTP server. This can also be used to
move files between directories.

## Usage

``` r
sftp_rename(
  sftp_conn,
  remote_url_from = NULL,
  remote_url_to = NULL,
  .recursive = FALSE,
  .verbose = TRUE
)
```

## Arguments

- sftp_conn:

  An `SFTPConn` R6 object, created by
  [`sftp_connect`](https://mikuo0628.github.io/sftpR/reference/sftp_connect.md).

- remote_url_from:

  Character. The current path of the file or directory.

- remote_url_to:

  Character. The new path for the file or directory.

- .recursive:

  Logical. If `TRUE`, automatically creates any missing parent
  directories in the destination path using
  [`sftp_mkdir`](https://mikuo0628.github.io/sftpR/reference/sftp_mkdir.md).
  Defaults to `FALSE`.

- .verbose:

  Logical. Defaults to `TRUE`. Prints helpful messages.

## Value

`invisible(TRUE)` on success.

## Details

The SFTP protocol's `rename` command is typically non-overwriting. If
`remote_url_to` already exists, the operation will fail.

When `.recursive = TRUE`, the function extracts the directory component
of `remote_url_to` and ensures it exists on the server before attempting
the rename.

## Examples

``` r
if (FALSE) { # \dontrun{
# Simple rename in the same folder
sftp_rename(sftp_conn, "old_name.csv", "new_name.csv")

# Move a file to a new, potentially non-existent directory
sftp_rename(
  sftp_conn,
  "data/raw.csv",
  "archive/2026/processed.csv",
  .recursive = TRUE
)
} # }
```
