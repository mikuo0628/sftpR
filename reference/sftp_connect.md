# Create an `SFTPConn` R6 object that contains important connection information safely.

An R6 class to safely store information needed for SFTP connection, with
convenient methods to check connections and existence of files or
directories, and create specific handles that are used in `sftp_*`
functions for CRUD operations.

## Usage

``` r
sftp_connect(
  protocol = "sftp",
  hostname = "localhost",
  path = NULL,
  port = "22",
  user = NA_character_,
  password = NA_character_,
  timeout = 30L,
  ...,
  .verbose = TRUE
)
```

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

## Details

One important goal of this designing choice is to keep user credentials
safe, as private fields. They are used downstream to create necessary
handles for specific SFTP operations, and users do not need to reenter
them. This class has a safe printing method for some basic information,
and to ensure credential is valid for connection.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create a new SFTP connection
sftp_conn <- sftp_connect(
  hostname = "127.0.0.1",
  port     = 2222,
  user     = "tester",
  password = "password123"
)
} # }
```
