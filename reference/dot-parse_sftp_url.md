# Parse and Validate SFTP URL Components

Internal utility to deconstruct an SFTP URL into its constituent parts
(protocol, user, hostname, port, and path). It enforces security by
disallowing absolute paths (indicated by double slashes) and performs
basic sanitization.

## Usage

``` r
.parse_sftp_url(url, .verbose = TRUE)
```

## Arguments

- url:

  A character string containing the SFTP URL.

- .verbose:

  Logical. Defaults to `TRUE`. Prints helpful messages.

## Value

A named list containing:

- protocol:

  The scheme (e.g., "sftp").

- user:

  The username if provided (e.g., "john").

- hostname:

  The server address (IPv4, IPv6, or domain).

- port:

  The port number as a string.

- path:

  The file or directory path relative to the home directory.

## Details

The function uses a single-pass regular expression to extract
components. It specifically blocks "Root Access" attempts (e.g.,
\`sftp://host//etc\`) by checking if the captured path starts with a
forward slash.
