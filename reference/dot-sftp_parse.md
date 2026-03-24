# Parse SFTP Directory Listings into Data Frames

A utility function that converts the raw binary content of an SFTP
directory listing (returned by `curl`) into a structured R `data.frame`.

## Usage

``` r
.sftp_parse(resp = NULL, sftp_url = NULL, h = NULL)
```

## Arguments

- resp:

  A response list from
  [`curl::curl_fetch_memory`](https://jeroen.r-universe.dev/curl/reference/curl_fetch.html).
  If `NULL`, the function will attempt to fetch data using `sftp_url`
  and `h`.

- sftp_url:

  Character. The SFTP URL to fetch if `resp` is `NULL`. This function
  will assume URL is valid (ie. dir or file).

- h:

  A `curl` handle. Required only if `resp` is `NULL`.

## Value

A `data.frame` with parsed Unix-style directory metadata, or `NULL` if
the directory is empty.

## Details

The function automatically filters out the special Unix directory
entries `"."` and `".."`. It determines object types based on the first
character of the permission string (e.g., 'd' for directory).
