# Delete Files or Directories from SFTP Server

Deletes a specific file or directory from the remote server. If the
target is a directory, it must be empty unless `.recursive = TRUE` is
specified.

## Usage

``` r
sftp_delete(
  sftp_conn,
  remote_url = NULL,
  .recursive = FALSE,
  .verbose = TRUE,
  .validate = TRUE
)
```

## Arguments

- sftp_conn:

  An `SFTPConn` R6 object, created by
  [`sftp_connect`](https://mikuo0628.github.io/sftpR/reference/sftp_connect.md).

- remote_url:

  Character. The full URL or path of the file or directory to be
  deleted.

- .recursive:

  Logical. If `TRUE`, will recursively list and delete all contents
  within a directory before deleting the directory itself. Defaults to
  `FALSE`.

- .validate:

  Logical. Whether to validate the `remote_url` against the connection
  object. Internally set to `FALSE` during recursive calls to improve
  performance.

## Value

`TRUE` (invisibly) if the operation was successful.

## Safety Warnings

- **Irreversibility:** Deletion on SFTP is permanent. There is no
  "Trash" or "Recycle Bin" on most SFTP server configurations.

- **Recursive Caution:** Setting `.recursive = TRUE` on a high-level
  directory can result in significant data loss. Always verify the
  `remote_url` before executing.

## Examples

``` r
if (FALSE) { # \dontrun{
# Delete a single file
sftp_delete(sftp_conn, "project/old_report.csv")

# Delete an entire directory and its contents
sftp_delete(sftp_conn, "project/temp_outputs/", .recursive = TRUE)
} # }
```
