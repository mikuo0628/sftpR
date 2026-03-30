# Shared Parameter Documentation

Shared Parameter Documentation

## Arguments

- protocol:

  Character. Protocol string. Defaults to "sftp".

- hostname:

  Character. Server URL or IP. Defaults to "localhost".

- path:

  Character. Sub-path on server.

- port:

  Character. Port number. Defaults to "22".

- user:

  Character. SFTP account name.

- password:

  Character. SFTP password.

- timeout:

  Integer. Connection timeout.

- ...:

  Additional arguments passed to
  [`curl::handle_setopt()`](https://jeroen.r-universe.dev/curl/reference/handle.html).

- .verbose:

  Logical. Defaults to `TRUE`. Prints helpful messages.

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

  - [`sftp_mkdir()`](https://mikuo0628.github.io/sftpR/reference/sftp_mkdir.md):
    creates all the missing parent directories.

  - [`sftp_rename()`](https://mikuo0628.github.io/sftpR/reference/sftp_rename.md):
    see
    [`sftp_mkdir()`](https://mikuo0628.github.io/sftpR/reference/sftp_mkdir.md).

- .create_dir:

  Logical. Defaults to `FALSE`. If `TRUE`, creates the necessary parent
  directories if needed.
