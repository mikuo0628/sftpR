# [sftpR](https://mikuo0628.github.io/sftpR/)

Robust SFTP tool kit for R, built on top of
[`curl`](https://cran.r-project.org/package=curl).

This package is inspired by [`sftp`](https://github.com/stenevang/sftp),
with modernized updates that shifts from the legacy
[`RCurl`](https://cran.r-project.org/package=RCurl) to the more secure
[`curl`](https://cran.r-project.org/package=curl) that is still
[issue-tracked and maintained](https://jeroen.r-universe.dev/curl), a
more robust handling of inputs and paths, and more secure management of
user credentials.

`sftpR` leverages an R6 class for connection that safely stores user
credential and a reusable `curl` handle for generic SFTP operations such
as download and listing directories, and interal methods to create
purpose-driven handles for more specific SFTP operations (upload,
delete, rename, etc).

## Installation

You can install the stable version of the package from CRAN:

``` r
install.packages("sftpR")
```

And the development version from GitHub:

``` r
# install.packages("devtools")
devtools::install_github("mikuo0628/sftpR")
```

## Quick Start

``` r
# Establish connection (see ?sftp_connect for detail)
sftp_conn <- 
  sftp_connect(
    hostname = "127.0.0.1",
    port     = "2222",
    user     = "tester",
    password = "password123"
  )

# List a remote directory
sftp_list(sftp_conn, .recursive = T)
sftp_list(sftp_conn, "127.0.0.1/upload", .recursive = T)

# Upload
## a data frame
sftp_upload(sftp_conn, local_file = mtcars, "upload/mtcars.csv")
## a local file
sftp_upload(sftp_conn, local_file = "/home/path/file.txt", "upload/file.txt")

# Download
sftp_download(sftp_conn, "upload/file.txt")

# Create a remote directory
sftp_mkdir(sftp_conn, "upload/archive")

# Rename / Move
sftp_rename(sftp_conn, "upload/file.txt", "upload/archive/file.backup")
```

## Notes and Requirements

- This package relies on `libcurl` with SFTP support (libssh2).

## Contributing

- Please open issues or pull requests. Follow the existing code stles
  and update/include tests for behavioural changes.
