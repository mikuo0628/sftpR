# sftpR

Robust SFTP tooling for R built on top of the
[`curl`](https://cran.r-project.org/web/packages/curl/index.html)
package.

This package is inspired by [`sftp`](https://github.com/stenevang/sftp),
with updates to a more robust handling of inputs and paths, secure
management of user credentials, and modern backend.

It provides an R6-based connection object that maintains user credential
safely and a reusable `curl` handle, with public methods for safe
printing and connection checking, and creating private purpose-specific
handles (upload, rename, mkdir, etc).

It also comes with the typical core CRUD functions to perform common
SFTP operations, while reusing a single `curl` handle when appropriate.

## Installation

You can install the development version of sftpR from
[GitHub](https://github.com/) with:

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
