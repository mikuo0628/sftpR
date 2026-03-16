# sftpR — Develoment design, plan, and progress
 
This repository is an R package providing small helpers for SFTP
operations using libcurl. The following notes on design, planning, and
tracking are intended for agents and contributors to quickly understand the project's structure, core APIs, return objects, and common pitfalls.

**Project Layout**
- **Files:** DESCRIPTION, NAMESPACE, sftpR.Rproj
- **Implementation:** R/
- **Docs:** man/ (generated from roxygen)
- **Environment:** renv/ (use `Rscript -e "renv::restore()"` to reproduce)

**High-level overview**
- `R/sftp_connect.R` defines an `SFTPConn` R6 class generator
(`sftp_conn_generator`) and a convenience constructor 
`sftp_connect()` that returns an `SFTPConn` object. The object
encapsulates credentials and a `curl` handle for reuse.
- `R/sftp_upload.R`, `R/sftp_list.R`, `R/sftp_download.R`,
`R/sftp_delete.R`, `R/sftp_mkdir.R`, and `R/sftp_rename.R`
implement exported helpers that accept an `SFTPConn` instance and
perform remote operations.
- `R/utils.R` contains URL parsing, building, and validation helpers:
`.parse_sftp_url()`, `.build_sftp_url()`, and `.validate_sftp_url()`.

Important: the package expects system `libcurl` with SFTP support.
The code checks this at runtime via `curl::curl_version()$protocol`.

**Return objects and core types**
- `SFTPConn` (R6 object): primary return type from
`sftp_connect()` / `sftp_conn_generator`. Key parts:
  - Public fields: `protocol`, `hostname`, `path`, `port`, `timeout`,
  `h`, `.verbose`.
  - Public methods: 
    - `initialize(...)`, 
    - `connection_ok() -> logical`,
    - `print()` (invisible `self`), 
    - `.upload_handle(local_file, ...) -> list(h, file_conn, tempfile)`,
    - `.quote_handle(...) -> curl handle`,
    - `.exists(sftp_url) -> logical`,
    - `.fix_url_type(remote_url) -> character`.
  - Active binding: 
    - `clean_url` -> returns list(full_url, protocol, user, hostname,
    port, path) from `.build_sftp_url()`.
  - Private fields: 
    - `user`, 
    - `password`, 
    - `.base_handle(...) -> curl handle`.

**Exported function contracts**
**Exported function contracts (with curl options & URL expectations)**

- `sftp_connect(protocol, hostname, path, port, user, password, timeout, ..., .verbose = TRUE)`
  - Returns: an `SFTPConn` R6 object (the result of `sftp_conn_generator`).
  - Curl handle options set by `SFTPConn` (`private$.base_handle`):
    - `userpwd = "user:password"` (from private credentials)
    - `ssh_auth_types = 2` (SSH password auth)
    - `verbose = .verbose` and `timeout = <timeout>`
    - Accepts additional `curl::handle_setopt()` args passed via `...`
    (e.g., `connecttimeout`, `nobody`, `range`).
  - URL expectation: `sftp_connect` accepts `hostname` values that may include
  protocol, port, user, or path; `.build_sftp_url()` normalizes them
  into the connection's `clean_url` (full_url).
  Clients normally use relative paths against `sftp_conn$clean_url$full_url`
  for operations.

- `sftp_upload(sftp_conn, local_file, remote_file = NULL, .create_dir = FALSE, .verbose = TRUE)`
  - Purpose: upload local files or data.frames to the server.
  - Curl options used (via `SFTPConn$.upload_handle`):
    - `upload = TRUE` to enable PUT/stream upload
    - `readfunction` / `seekfunction` callbacks to stream file content
    - `forbid_reuse` is set based on `reuse` argument
    - `infilesize_large` is set when local file size is known
    - optional: `ftp_create_missing_dirs = 1L` when `.create_dir = TRUE`
  - Execution: uses `curl::curl_fetch_memory(remote_file, handle = upload_h$h)`
  where `remote_file` is the normalized full URL returned
  by `.validate_sftp_url()`.
  - URL expectation: accepts relative remote paths (recommended) — these
  are validated and expanded by `.validate_sftp_url()` into a full absolute URL
  using the connection's `clean_url`. Absolute URLs are accepted but will be
  normalized.
  - Return: `invisible(TRUE)` on success; throws on error.

- `sftp_list(sftp_conn, sftp_url = NULL, .verbose = TRUE, .recursive = FALSE, .check = .recursive)`
  - Purpose: list directory contents and optionally crawl recursively.
  - Curl options used:
    - Uses the connection handle `sftp_conn$h`
    (created from `private$.base_handle`) with default connection options.
    - Internally may call `.fix_url_type()` which probes with `range = "0-0"`
    and a short `connecttimeout` to determine file vs directory.
  - Execution: `curl::curl_fetch_memory(sftp_url, sftp_conn$h)` is used
  to retrieve directory listing content which `.sftp_parse()` converts
  to a `data.frame`.
  - URL expectation: if `sftp_url` is `NULL`,
  uses `sftp_conn$clean_url$full_url`.
  - If provided, relative paths are allowed and validated via
  `.validate_sftp_url()`; trailing slash conventions matter
  (directories should have a trailing slash) and `.fix_url_type()`
  attempts to normalize.

- `sftp_download(sftp_conn, path_file, path_save, .verbose = TRUE, ...)`
  - Purpose: download files from the server.
  - Curl options used / expected:
    - Should use `sftp_conn$h` for authentication and reuse.
    - Expected to call `curl::curl_download(url, destfile, handle = sftp_conn$h)`
    using `quiet`, `progress` options as desired.
    - Implementation note: function currently contains `browser()` and
    several TODOs; it's not considered production-ready.
  - URL expectation: accepts relative paths
  (validated via `.validate_sftp_url()`) or full URLs; when downloading multiple
  files, callers must ensure `path_save` maps 1:1 or is a directory.

- `sftp_delete(sftp_conn, remote_url, .verbose = TRUE)`
  - Purpose: remove a remote file or directory (directory must be empty).
  - Curl options used:
    - Builds a command-style handle via
    `sftp_conn$.quote_handle(..., purpose = "rm")` which sets `quote` and uses
    `private$.base_handle()` for user credentials.
    - Execution via
    `curl::curl_fetch_memory(sftp_conn$clean_url$full_url, handle = h)`.
  - URL expectation: accepts relative paths (recommended) and normalizes via 
  `.validate_sftp_url()`; `.quote_handle` strips the base URL and uses a
  relative path in the server-side command.
  - Return: `invisible(TRUE)` on success; throws on failure.

- `sftp_mkdir(sftp_conn, remote_url, .recursive = TRUE, .verbose = TRUE)`
  - Purpose: create directories on the remote server.
  - Curl options used:
    - Uses `sftp_conn$.quote_handle(..., purpose = "mkdir")` which can set
    `ftp_create_missing_dirs` when `.recursive = TRUE`.
    - Under the hood uses `private$.base_handle()` for credentials and may call
    `curl::curl_fetch_memory()` to execute the MKD command.
  - URL expectation: relative paths are recommended; normalized through `.
  validate_sftp_url()`.
  - Note: current implementation contains `browser()` and should have that
  removed before running checks.

- `sftp_rename(sftp_conn, remote_url_from, remote_url_to, .recursive = FALSE, .verbose = TRUE)`
  - Purpose: rename or move remote resources.
  - Curl options used:
    - Constructs a rename command via 
    `sftp_conn$.quote_handle(..., purpose = "rename")` which sets a
    `quote` string appropriate to the protocol and uses `private$.base_handle()`
    for credentials.
    - Executes with
    `curl::curl_fetch_memory(sftp_conn$clean_url$full_url, handle = h)`.
  - URL expectation: accepts relative paths
  (validated via `.validate_sftp_url()`); ensures destination parent exists
  (creates it via `sftp_mkdir()` when needed).
  - Return: `invisible(TRUE)` on success.

**Key internal helpers (in `R/utils.R`)**
- `.parse_sftp_url(url)` -> named list(protocol, user, hostname, port, path).
Rejects absolute `//` root-access attempts.
- `.build_sftp_url(protocol, user, hostname, port, path)` -> 
list(full_url, protocol, user, hostname, port, path).
- `.validate_sftp_url(sftp_conn, user_url)` -> 
sanitized `full_url` string; compares parsed parts against
`sftp_conn$clean_url` and warns/replaces mismatches.
- `.sftp_parse(resp, sftp_url, h)` ->
parse `ls -l` style response to a `data.frame`.

**Usage examples (copyable snippets)**

- Create a connection and inspect it:

  sftp_conn <- sftp_connect(
    hostname = "127.0.0.1",
    port = 2222,
    user = "tester",
    password = "password123",
    .verbose = TRUE
  )

  # Inspect base URL and curl handle
  sftp_conn$clean_url$full_url
  sftp_conn$h

- Uploading a data.frame (writes to temp CSV automatically):

  sftp_upload(
    sftp_conn = sftp_conn,
    local_file = mtcars,                      # data.frame -> temp file
    remote_file = "upload/mtcars.csv",
    .create_dir = TRUE,
    .verbose = TRUE
  )

- Listing a folder (non-recursive):

  df <- sftp_list(sftp_conn, "upload/", .recursive = FALSE)

- Deleting a file:

  sftp_delete(sftp_conn, "upload/mtcars.csv")

- Creating a nested folder (recursive):

  sftp_mkdir(sftp_conn, "upload/subdir", .recursive = TRUE)

- Renaming/moving a file:

  sftp_rename(
    sftp_conn,
    remote_url_from = "upload/old.csv",
    remote_url_to = "upload/new.csv",
    .recursive = TRUE
  )

**Tests & expectations**
- Tests in `tests/testthat/` exercise URL parsing, URL building,
validation logic, `SFTPConn` construction, and an example workflow that uploads,
lists, deletes, and creates directories.
- Unit tests expect specific warnings in scenarios where arguments are
overwritten by parsed hostname parts (e.g., passing
`hostname = "sftp://127.0.0.1:2222/"` should warn about overwriting `port`).

**Developer guidance & checklist**
- Remove `browser()` calls in `R/sftp_connect.R`, `R/sftp_download.R`,
and `R/sftp_mkdir.R` before submitting a PR or running `R CMD check`.
- Avoid committing plaintext credentials. Prefer `keyring::key_get()`
or environment variables.
- If you add new runtime dependencies, add them to `DESCRIPTION::Imports`
and run `Rscript -e "renv::snapshot()"`.
- Regenerate documentation with `Rscript -e "devtools::document()"`
(or `roxygen2::roxygenize()`).

**API quick reference (method signatures & returns)**
- `sftp_connect(protocol = "sftp", hostname, path = NULL, port = 22L, user = NA_character_, password = NA_character_, timeout = 30L, ..., .verbose = TRUE)` -> `SFTPConn` R6 object.
- `SFTPConn$connection_ok()` -> logical
- `SFTPConn$print()` -> invisible(self)
- `SFTPConn$.upload_handle(local_file, reuse = TRUE, .verbose = TRUE, ...)` ->
list(h = curl_handle, file_con = connection, tempfile = path_or_NULL)
- `SFTPConn$.exists(sftp_url)` -> logical
- `SFTPConn$.fix_url_type(remote_url)` -> character (possibly toggled trailing slash)
- `sftp_upload(...)` -> `invisible(TRUE)` on success
- `sftp_list(...)` -> `data.frame` or `NULL`
- `sftp_delete(...)`, `sftp_mkdir(...)`, `sftp_rename(...)` ->
`invisible(TRUE)` on success
