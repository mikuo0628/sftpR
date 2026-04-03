# Upload a file to an SFTP server

A robust wrapper to upload local files or data frames to a remote SFTP
server. It manages the libcurl handle lifecycle, ensures connections are
closed, and validates URLs against the connection's "Source of Truth".

## Usage

``` r
sftp_upload(
  sftp_conn,
  local_file,
  remote_file = NULL,
  .create_dir = FALSE,
  .verbose = TRUE
)
```

## Arguments

- sftp_conn:

  An `SFTPConn` object containing connection details and authentication.
  Created by
  [`sftp_connect`](https://mikuo0628.github.io/sftpR/reference/sftp_connect.md).

- local_file:

  Character string (path to a file) or a `data.frame`. Data frames are
  automatically written to a temp file before upload. The temp file will
  automatically be cleaned up at the end of function.

- remote_file:

  Character string. The destination path on the server. If `NULL`,
  attempts to use the basename of the `local_file`.

- .create_dir:

  Logical. Defaults to `FALSE`. If `TRUE`, creates the necessary parent
  directories if needed.

- .verbose:

  Logical. Defaults to `TRUE`. Prints helpful messages.

## Value

Returns `TRUE` (invisibly) on success. Throws an error on failure.

## Details

The function uses a secure lifecycle:

1.  Validates the remote URL to prevent credential leakage.

2.  Opens a file connection to the local source.

3.  Uses `on.exit` to ensure file handles are released and temporary
    files are unlinked even if the transfer is interrupted.

## Examples

``` r
# \donttest{
if (interactive() || Sys.getenv("R_SFTP_TEST_SERVER") == "true") {
  # Create new SFTP connection
  sftp_conn <- sftp_connect(
    hostname = "127.0.0.1",
    port     = "2222",
    user     = "tester",
    password = "password123"
  )

  # Upload `my_df` as csv
  sftp_upload(conn, my_df, "uploads/data.csv")
}
# }
```
