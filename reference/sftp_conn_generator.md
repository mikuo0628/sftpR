# SFTP Connection Class

An R6 class to safely store information needed for SFTP connection, with
convenient methods to check connections and existence of files or
directories, and create specific handles that are used in `sftp_*`
functions for CRUD operations.

## Details

One important goal of this designing choice is to keep user credentials
safe, as private fields. They are used downstream to create necessary
handles for specific SFTP operations, and users do not need to reenter
them. This class has a safe printing method for some basic information,
and to ensure credential is valid for connection.

## Note

This method uses a 5-second `connecttimeout` to ensure the probe doesn't
hang on unresponsive servers.

## Public fields

- `protocol`:

  The connection protocol.

- `hostname`:

  The server address or IP.

- `path`:

  The target subdirectory on the server.

- `port`:

  The port number.

- `timeout`:

  Connection timeout in seconds.

- `h`:

  The internal curl handle used for connection checks, listing
  directories, and download files.

- `.verbose`:

  Logical; if TRUE, prints detailed curl output.

- `last_error`:

  Character string of the last connection error.

## Active bindings

- `clean_url`:

  Returns the processed SFTP URL via internal `.build_sftp_url`.

## Methods

### Public methods

- [`sftp_conn_generator$new()`](#method-SFTPConn-new)

- [`sftp_conn_generator$connection_ok()`](#method-SFTPConn-connection_ok)

- [`sftp_conn_generator$print()`](#method-SFTPConn-print)

- [`sftp_conn_generator$.upload_handle()`](#method-SFTPConn-.upload_handle)

- [`sftp_conn_generator$.quote_handle()`](#method-SFTPConn-.quote_handle)

- [`sftp_conn_generator$.exists()`](#method-SFTPConn-.exists)

- [`sftp_conn_generator$.fix_url_type()`](#method-SFTPConn-.fix_url_type)

- [`sftp_conn_generator$clone()`](#method-SFTPConn-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize \`SFTPConn\` class R6 object.

#### Usage

    sftp_conn_generator$new(
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

#### Arguments

- `protocol`:

  Character. Protocol string. Defaults to "sftp".

- `hostname`:

  Character. Server URL or IP. Defaults to "localhost".

- `path`:

  Character. Sub-path on server.

- `port`:

  Character. Port number. Defaults to "22".

- `user`:

  Character. SFTP account name.

- `password`:

  Character. SFTP password.

- `timeout`:

  Integer. Connection timeout.

- `...`:

  Additional arguments passed to
  [`curl::handle_setopt()`](https://jeroen.r-universe.dev/curl/reference/handle.html).

- `.verbose`:

  Logical. Defaults to `TRUE`. Prints helpful messages.

#### Returns

An \`SFTPConn\` object with safely stored user credential and
convenience methods for various operations, such as checking connection
and existence, and creating handles for CRUD operations.

------------------------------------------------------------------------

### Method `connection_ok()`

Checks if the current connection settings and credentials are valid.

#### Usage

    sftp_conn_generator$connection_ok()

#### Returns

Logical; TRUE if connection is successful.

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Custom print method to display connection status without exposing
passwords.

#### Usage

    sftp_conn_generator$print(...)

#### Arguments

- `...`:

  Unused.

------------------------------------------------------------------------

### Method `.upload_handle()`

Internal method to generate a specialized upload handle with streaming.
Adapted from
[`curl::curl_upload()`](https://jeroen.r-universe.dev/curl/reference/curl_upload.html).

#### Usage

    sftp_conn_generator$.upload_handle(
      local_file,
      reuse = TRUE,
      .verbose = self$.verbose,
      ...
    )

#### Arguments

- `local_file`:

  Path to file, data.frame, or connection.

- `reuse`:

  Logical; try to keep connection alive.

- `.verbose`:

  Logical. Defaults to `TRUE`. Prints helpful messages.

- `...`:

  Additional options for
  [`curl::handle_setopt()`](https://jeroen.r-universe.dev/curl/reference/handle.html).

------------------------------------------------------------------------

### Method `.quote_handle()`

Createshandle that uses \`quote\` option. Specifically for deleting,
creating directories, and renaming files or directories.

#### Usage

    sftp_conn_generator$.quote_handle(
      remote_url_from = NULL,
      remote_url_to = NULL,
      purpose = c("rm", "mkdir", "rename"),
      .verbose = self$.verbose,
      .ignore_error = FALSE,
      ...
    )

#### Arguments

- `remote_url_from`:

  Character. The URL to delete, to create, or to rename from.

- `remote_url_to`:

  Character. The URL to rename to. Ignored for delete or directory
  create operations.

- `purpose`:

  Character. Choose one of 3 options:

  - "rm": to delete file or directory.

  - "mkdir": to create directory. Path should be a directory.

  - "rename": to rename

- `.verbose`:

  Logical. Defaults to `TRUE`. Prints helpful messages.

- `.ignore_error`:

  Logical. Defaults to \`FALSE\`. If `TRUE`, error will not interrupt
  subsequent execution. See \`Details\`.

- `...`:

  Options that for
  [`curl::handle_setopt()`](https://jeroen.r-universe.dev/curl/reference/handle.html).

#### Details

In \`curl\`, adding an asterisk (\`\*\`) at the very beginning of a
command (ie. one of the 3 used in \`purpose\` argument) acts as a
"fail-safe" or "ignore-error" prefix. It silently ignores any failure
returned by the command, and continues without being interrupted by the
error. Check if a remote path exists

------------------------------------------------------------------------

### Method `.exists()`

An internal helper that pings the SFTP/FTP server to verify the
existence of a file or directory.

#### Usage

    sftp_conn_generator$.exists(sftp_url = NULL)

#### Arguments

- `sftp_url`:

  Character. The full URL to the remote resource. If `NULL`, returns
  `FALSE`.

#### Details

This method uses `CURLOPT_NOBODY = TRUE` to perform a protocol-level
`STAT` request. This is highly efficient as it retrieves only metadata
and does not attempt to download or list contents.

Because `STAT` is slash-agnostic in the SFTP protocol, this check will
return `TRUE` for a directory regardless of whether a trailing
forward-slash is provided in the URL.

However, this is the only operation where URL is "safe" from the
consequences of un-normalized URLs. Be wary of incorrect multiple slash
placements as they will be collapsed into one slash and won't throw
errors.

#### Returns

Logical. `TRUE` if the resource exists and is accessible; `FALSE`
otherwise. URL "fixing" via range probing

------------------------------------------------------------------------

### Method `.fix_url_type()`

An internal diagnostic method that determines if a remote URL requires a
trailing slash by attempting to read a single byte (Range: 0-0).

#### Usage

    sftp_conn_generator$.fix_url_type(remote_url)

#### Arguments

- `remote_url`:

  Character. The full SFTP/FTP URL to validate.

#### Details

This method leverages a protocol behavior:

- **Files** allow byte-range requests; the probe succeeds.

- **Directories** reject byte-range requests; the probe fails.

If the initial probe fails, the method "flips" the trailing slash (adds
one if missing, or removes one if present) and returns the modified URL.
This addresses the common \`libcurl\` issue where directory listings
fail without an explicit trailing slash.

#### Returns

A character string containing the "fixed" URL. Note that if the path
truly does not exist, the flipped URL is still returned; the final
operation (upload/list) will handle the ultimate failure.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    sftp_conn_generator$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
