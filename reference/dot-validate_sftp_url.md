# Validate and Sanitize SFTP URLs against a Connection Object

This internal utility ensures that a user-provided URL matches the
"Source of Truth" defined in an `SFTPConn` object. It prevents common
formatting errors, warns against security-risky root access attempts
(double slashes), and corrects any incongruities in the protocol,
hostname, or port.

## Usage

``` r
.validate_sftp_url(sftp_conn, user_url, .verbose = sftp_conn$.verbose)
```

## Arguments

- sftp_conn:

  An `SFTPConn` object containing connection details and authentication.
  Created by
  [`sftp_connect`](https://mikuo0628.github.io/sftpR/reference/sftp_connect.md).

- user_url:

  Character string. The destination SFTP URL or path provided by the
  user.

- .verbose:

  Logical. Defaults to `TRUE`. Prints helpful messages.

## Value

A sanitized character string containing the validated SFTP URL.

## Details

The function performs the following steps:

- Checks for empty inputs.

- Detects and "heals" double-slash root access attempts (e.g.,
  \`sftp://host//path\` becomes \`sftp://host/path\`).

- Deconstructs the URL using regular expressions to compare its
  components against the \`sftp_conn\` settings.

- Issues a warning if the user-provided protocol, hostname, or port
  differs from the established connection.

- Reconstructs a clean, standardized URL.
