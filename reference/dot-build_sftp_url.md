# Build SFTP URL components

Helper (stateless) function to construct a full SFTP URL and its
components from the given protocol, hostname, port, and path Hostname
will be sanitized for minor formatting issues; if a port or path are
found inside \`hostname\` they will override the corresponding
arguments.

## Usage

``` r
.build_sftp_url(
  protocol = "sftp",
  user = NULL,
  hostname = NULL,
  port = "22",
  path = NULL,
  .verbose = TRUE
)
```

## Arguments

- protocol:

  Character. Protocol string. Defaults to "sftp".

- user:

  Character. SFTP account name.

- hostname:

  Character. Server URL or IP. Defaults to "localhost".

- port:

  Character. Port number. Defaults to "22".

- path:

  Character. Sub-path on server.

- .verbose:

  Logical. Defaults to `TRUE`. Prints helpful messages.

## Value

A list with components: full_url, protocol, hostname, port, path.
