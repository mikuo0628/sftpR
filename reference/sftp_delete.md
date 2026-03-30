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

  An `SFTPConn` object containing connection details and authentication.
  Created by
  [`sftp_connect`](https://mikuo0628.github.io/sftpR/reference/sftp_connect.md).

- remote_url:

  Character. The full URL or path of the file or directory to be
  operated on.

- .recursive:

  Logical. Defaults to `FALSE`. If `TRUE`, will recursively perform the
  SFTP operation:

  - `sftp_delete()`: deletes the directory and everything within.

  - [`sftp_list()`](https://mikuo0628.github.io/sftpR/reference/sftp_list.md):
    lists all the directories and files.

  - [`sftp_mkdir()`](https://mikuo0628.github.io/sftpR/reference/sftp_mkdir.md):
    creates all the missing parent directories.

  - [`sftp_rename()`](https://mikuo0628.github.io/sftpR/reference/sftp_rename.md):
    see
    [`sftp_mkdir()`](https://mikuo0628.github.io/sftpR/reference/sftp_mkdir.md).

- .verbose:

  Logical. Defaults to `TRUE`. Prints helpful messages.

- .validate:

  Logical. Whether to validate the `remote_url` against the connection
  object. Defaults to `TRUE`, which will parse `remote_url`, comapre to
  that of `SFTPConn`, and replaces parts incongruent with `SFTPConn`.
  Internally set to `FALSE` when `.recursive = TRUE` because the URLs
  produced by the listing operation aren't subjected to human errors,
  thus do not need further validation. This provides a minor performance
  boost.

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
