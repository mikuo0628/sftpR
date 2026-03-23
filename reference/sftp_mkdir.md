# Create Remote Directories via SFTP

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

  An `SFTPConn` R6 object, created by
  [`sftp_connect`](https://mikuo0628.github.io/sftpR/reference/sftp_connect.md).

- remote_url:

  Character. The relative or absolute path of the directory to create.

- .recursive:

  Logical. If `TRUE`, creates missing parent directories. Defaults to
  `TRUE`.

- .verbose:

  Logical. Defaults to `TRUE`. Prints helpful messages.

- .ignore_error:

  Logical. If `FALSE`, the function uses the `*` prefix in the curl
  quote command to ignore errors (e.g., if the directory already
  exists). Defaults to `!.recursive`.

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
