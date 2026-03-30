# Create Remote Directories in SFTP

This function creates directories on a remote server using the SFTP
protocol. It supports recursive directory creation, effectively behaving
like `mkdir -p` on a Unix-like system.

## Usage

``` r
sftp_mkdir(
  sftp_conn,
  remote_url = NULL,
  .recursive = TRUE,
  .verbose = TRUE,
  .ignore_error = .recursive
)
```

## Arguments

- sftp_conn:

  An `SFTPConn` object containing connection details and authentication.
  Created by \[sftp_connect()\].

- remote_url:

  Character. The full URL or path of the file or directory to be
  operated on.

- .recursive:

  Logical. Defaults to `FALSE`. If `TRUE`, will recursively perform the
  SFTP operation:

  - [`sftp_delete()`](https://mikuo0628.github.io/sftpR/reference/sftp_delete.md):
    deletes the directory and everything within.

  - [`sftp_list()`](https://mikuo0628.github.io/sftpR/reference/sftp_list.md):
    lists all the directories and files.

  - `sftp_mkdir()`: creates all the missing parent directories.

  - [`sftp_rename()`](https://mikuo0628.github.io/sftpR/reference/sftp_rename.md):
    see `sftp_mkdir()`.

- .verbose:

  Logical. Defaults to `TRUE`. Prints helpful messages.

- .ignore_error:

  Logical. If `TRUE`, the function uses the `*` prefix in the curl quote
  command to ignore errors (e.g., if the directory already exists). This
  is useful in `.recursive = TRUE` because attempting to create a
  directory that already exists will return error. While this can be
  avoided by checking for directory existence, doing so adds extra step
  that impacts performance.

## Value

`invisible(TRUE)` on success.

## Details

When `.recursive = TRUE`, the function splits the path into segments and
attempts to create each one sequentially. It uses the `*` prefix for
internal calls to ensure that existing directories do not trigger
errors.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create a nested directory structure
sftp_mkdir(sftp_conn, "project/data/results/2026", .recursive = TRUE)

# Create a single directory and fail if parents are missing
sftp_mkdir(sftp_conn, "simple_dir", .recursive = FALSE)
} # }
```
