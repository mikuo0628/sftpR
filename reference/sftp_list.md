# List and Crawl SFTP Directory Contents

Retrieves a directory listing from an SFTP server. If
`.recursive = TRUE`, it will perform a depth-first crawl of all
subdirectories found, implementing a path-tracking algorithm to detect
and skip circular symbolic links, preventing infinite recursion and
stack overflow errors.

## Usage

``` r
sftp_list(
  sftp_conn = NULL,
  sftp_url = NULL,
  .verbose = TRUE,
  .recursive = FALSE
)
```

## Arguments

- sftp_conn:

  An `SFTPConn` object containing connection details and authentication.
  Created by
  [`sftp_connect`](https://mikuo0628.github.io/sftpR/reference/sftp_connect.md).

- sftp_url:

  A SFTP URL of which the contents will be listed. If `NULL`, the base
  URL in `SFTPConn` will be used: contents of the SFTP home folder will
  be listed.

- .verbose:

  Logical. Defaults to `TRUE`. Prints helpful messages.

- .recursive:

  Logical. Defaults to `FALSE`. If `TRUE`, will recursively perform the
  SFTP operation:

  - [`sftp_delete()`](https://mikuo0628.github.io/sftpR/reference/sftp_delete.md):
    deletes the directory and everything within.

  - `sftp_list()`: lists all the directories and files.

  - [`sftp_mkdir()`](https://mikuo0628.github.io/sftpR/reference/sftp_mkdir.md):
    creates all the missing parent directories.

  - [`sftp_rename()`](https://mikuo0628.github.io/sftpR/reference/sftp_rename.md):
    see
    [`sftp_mkdir()`](https://mikuo0628.github.io/sftpR/reference/sftp_mkdir.md).

## Value

A `data.frame` containing remote file/directory metadata:

- `permission`: Unix-style permission string (e.g., "drwxr-xr-x").

- `nlink`: Number of hard links.

- `user`: Owner username.

- `group`: Owner group.

- `size`: File size in bytes.

- `month, day, time_year`: Timestamp components.

- `name`: File or directory name.

- `type`: Categorization as "dir" or "file".

- `url`: The source URL for that specific object.

## Examples

``` r
# \donttest{
if (interactive() || Sys.getenv("R_SFTP_TEST_SERVER") == "true") {
  # Create a new SFTP connection
  sftp_conn <- sftp_connect(
    hostname = "127.0.0.1",
    port     = "2222",
    user     = "tester",
    password = "password123"
  )

  # List recursively
  sftp_list(sftp_conn, .recursive = TRUE)
}
# }
```
