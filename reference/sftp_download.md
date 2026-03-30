# Download Files from SFTP Server

Downloads a file from a remote SFTP server to a local disk location or
directly into R's memory as a raw vector.

## Usage

``` r
sftp_download(
  sftp_conn,
  remote_file,
  local_file = NA_character_,
  .create_dir = FALSE,
  .overwrite = FALSE,
  .verbose = TRUE,
  ...
)
```

## Arguments

- sftp_conn:

  An `SFTPConn` object containing connection details and authentication.
  Created by \[sftp_connect()\].

- remote_file:

  Character. The path or URL of the file on the SFTP server.

- local_file:

  Character or `NULL`.

  - If `NA` (default) or an `""`: The file is saved to the current
    working directory while using `remote_file` filename.

  - If `character`: The local path where the file should be saved.

  - If `NULL`: The file is downloaded to memory and returned as a `raw`
    vector.

- .create_dir:

  Logical. Defaults to `FALSE`. If `TRUE`, creates the necessary parent
  directories if needed.

- .overwrite:

  Logical. Defaults to `FALSE`. If `TRUE`, will overwrite destination
  file.

- .verbose:

  Logical. Defaults to `TRUE`. Prints helpful messages.

- ...:

  Additional arguments passed to
  [`curl::curl_download`](https://jeroen.r-universe.dev/curl/reference/curl_download.html).

## Value

If `local_file` is `NULL`, a `raw` vector of the file contents.
Otherwise, the resolved local path to the saved file (invisibly).

## Local Path Resolution Caveats

To provide a "smart" user experience, the function guesses if
`local_file` is intended to be a directory or a specific filename:

- **Directory Detection:** If the path exists as a directory, ends in a
  trailing slash, or has no file extension, it is treated as a folder.
  The `remote_file` filename will be appended to this path.

- **File Detection:** If the path does not exist and contains a file
  extension (e.g., ".csv"), it is treated as the final destination
  filename.

- **Ambiguity:** In ambiguous cases (e.g., a non-existent path without a
  slash or extension), the function defaults to treating the path as a
  directory.

## Examples

``` r
if (FALSE) { # \dontrun{
# Download and use the remote filename
sftp_download(sftp_conn, "data/raw_logs.zip")

# Download to a specific local name
sftp_download(sftp_conn, "remote_file.csv", "local_name.csv")

# Download to memory for immediate processing
raw_bytes <- sftp_download(sftp_conn, "data.json", local_file = NULL)
data <- jsonlite::fromJSON(rawToChar(raw_bytes))
} # }
```
