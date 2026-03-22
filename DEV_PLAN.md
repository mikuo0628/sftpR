# sftpR — Development plan and API reference

This file is the authoritative developer plan for the sftpR package.
It documents project layout, the public API, internal helpers,
expected runtime/curl options, examples, tests, and actionable TODOs
for maintainers and agents.

## Project layout & quick start
- Files: `DESCRIPTION`, `NAMESPACE`, `sftpR.Rproj`
- Implementation: `R/`
- Docs: `man/` (generated from roxygen)
- Environment: `renv/` (recreate with `Rscript -e "renv::restore()"`)

Common commands:
- Restore environment: `Rscript -e "renv::restore()"`
- Regenerate docs: `Rscript -e "devtools::document()"`
- Build: `R CMD build .`
- Check: `R CMD check .` or `Rscript -e "devtools::check()"`

## High-level overview
- `R/sftp_connect.R`: defines `SFTPConn` (R6) via `SFTPConnGenerator` and
  the convenience constructor `sftp_connect()`.
- `R/sftp_upload.R`, `R/sftp_list.R`, `R/sftp_download.R`, `R/sftp_delete.R`,
  `R/sftp_mkdir.R`, `R/sftp_rename.R`: exported helpers operating on an `SFTPConn` object.
- `R/utils.R`: URL parsing, building, and validation helpers:
  `.parse_sftp_url()`, `.build_sftp_url()`, `.validate_sftp_url()`, `.sftp_parse()`.

Note: this package requires system `libcurl` with SFTP support.
The code checks `"sftp" %in% curl::curl_version()$protocol` during
connection initialization.

## `SFTPConn` (R6) reference
Public fields:
- `protocol`, `hostname`, `path`, `port`, `timeout`, `h`, `.verbose`

Public methods:
- `initialize(protocol, hostname, path, port, user, password, timeout, ..., .verbose)`
- `connection_ok() -> logical` — uses `curl::curl_fetch_memory(self$clean_url$full_url, handle = self$h)` to detect connectivity.
- `print()` — prints safe connection info (does not reveal credentials) and returns `invisible(self)`.
- `.upload_handle(local_file, reuse = TRUE, ..., .verbose)` -> list(h = curl_handle, file_conn = connection, tempfile = path_or_NULL). Configured for streaming uploads.
- `.quote_handle(remote_url_from = NULL, remote_url_to = NULL, purpose = c("rm","mkdir","rename"), ...)` -> curl handle executing quoted commands for command-style operations.
- `.exists(sftp_url) -> logical` — STAT-like probe via `nobody = TRUE`.
- `.fix_url_type(remote_url) -> character` — range-probe (`range = "0-0"`) to detect whether trailing slash is needed.

Active binding:
- `clean_url` — returns `.build_sftp_url(...)` output: `full_url`, `protocol`, `user`, `hostname`, `port`, `path`.

Private:
- `user`, `password`, `.base_handle(...)-> curl handle` which sets `userpwd`, `ssh_auth_types = 2`, `verbose`, `timeout`, and accepts extra `handle_setopt` args.

## Exported functions — signatures, behavior, curl options, URL expectations
For each exported function the guidance below documents what curl handle
options are used and whether the function expects relative or absolute
remote URLs.

### `sftp_connect(protocol = "sftp", hostname, path = NULL, port = 22L, user = NA_character_, password = NA_character_, timeout = 30L, ..., .verbose = TRUE)`
- Returns: an `SFTPConn` R6 object.
- Curl options (via `private$.base_handle`): `userpwd = "user:password"`,
  `ssh_auth_types = 2`, `verbose = .verbose`, `timeout = <timeout>`.
  Additional `...` arguments are forwarded to `curl::handle_setopt()`
  (e.g., `connecttimeout`, `nobody`, `range`).
- URL expectation: `hostname` may include protocol, user, port,
  or path — `.build_sftp_url()` normalizes into the connection's `clean_url`.
  Downstream operations normally use relative paths
  against `sftp_conn$clean_url$full_url`.

### `sftp_upload(sftp_conn, local_file, remote_file = NULL, .create_dir = FALSE, .verbose = TRUE)`
- Purpose: upload local files or `data.frame` objects.
- Curl options (configured by `SFTPConn$.upload_handle`): `upload = TRUE`,
  streaming `readfunction`/`seekfunction`, `forbid_reuse`
  (depending on `reuse`), `infilesize_large` when size known.
  When `.create_dir = TRUE`, `ftp_create_missing_dirs = 1L` may be set.
- Execution: performs `curl::curl_fetch_memory(remote_full_url, handle = upload_handle$h)`.
- URL expectation: relative remote paths are recommended; `.validate_sftp_url()`
  will expand relative paths into absolute `full_url` anchored at
  `sftp_conn$clean_url`. Absolute URLs are accepted but
  are normalized and verified.
- Return: `invisible(TRUE)` on success; throws on error.

### `sftp_list(sftp_conn, sftp_url = NULL, .verbose = TRUE, .recursive = FALSE, .check = .recursive)`
- Purpose: list directory contents; `.recursive = TRUE` crawls subdirectories.
- Curl options: uses `sftp_conn$h` (from `.base_handle()`). `.fix_url_type()`
  uses a small probe (`range = "0-0"` and short `connecttimeout`) to
  determine file vs directory and adjust trailing slash.
- Execution: `curl::curl_fetch_memory(sftp_url, sftp_conn$h)` then
  parse via `.sftp_parse()`.
- URL expectation: if `sftp_url` is `NULL` uses `sftp_conn$clean_url$full_url`.
  When providing a path, relative paths are allowed and validated via
  `.validate_sftp_url()`; directories should
  have trailing slash — `.fix_url_type()` will attempt to adjust.
- Return: `data.frame` of parsed `ls -l` output, or `NULL` if empty.

### `sftp_download(sftp_conn, remote_file, local_file = NA_character_, .create_dir = FALSE, .overwrite = FALSE, .verbose = TRUE, ...)`
- Purpose: download a remote file to disk or memory.
- Curl usage: calls `curl::curl_download(url, destfile, handle = sftp_conn$h, ...)`
  for file downloads or `curl::curl_fetch_memory(url, handle = sftp_conn$h)`
  for in-memory retrieval.
- Local path behavior: treats `local_file = NULL` -> memory (return `raw`),
  `local_file` missing/empty -> save to working directory,
  otherwise intelligently decide whether `local_file` is directory or file.
- URL expectation: accepts relative paths (validated by `.validate_sftp_url()`)
  or absolute full URLs.
- Status: contains implementation TODOs
  (bulk-download mapping, clearer error handling). See TODOs below.
- Return: `invisible(destfile)` for file downloads or raw vector for memory downloads.

### `sftp_delete(sftp_conn, remote_url, .verbose = TRUE)`
- Purpose: delete a remote file or empty directory.
- Curl usage: builds a command-like handle from `sftp_conn$.quote_handle(..., purpose = "rm")` which sets `quote` and uses credentials from `.base_handle()`. The command is executed with `curl::curl_fetch_memory(sftp_conn$clean_url$full_url, handle = h)`.
- URL expectation: callers provide relative paths (recommended); `.validate_sftp_url()` normalizes them. `.quote_handle` strips the base URL and uses a relative POSIX path in the server-side command.
- Return: `invisible(TRUE)` on success; throws on failure.

### `sftp_mkdir(sftp_conn, remote_url, .recursive = TRUE, .verbose = TRUE, .ignore_error = !.recursive)`
- Purpose: create a remote directory (optionally recursive).
- Curl usage: uses `sftp_conn$.quote_handle(..., purpose = "mkdir")`.
  When `.recursive = TRUE`, `ftp_create_missing_dirs` logic may be
  used for multi-level creation, and internal calls may set an `*` prefix to
  ignore errors for existing directories.
- URL expectation: relative paths recommended; normalized via `.validate_sftp_url()`.
- Return: `invisible(TRUE)` on success.

### `sftp_rename(sftp_conn, remote_url_from, remote_url_to, .recursive = FALSE, .verbose = TRUE)`
- Purpose: rename or move remote resources.
- Curl usage: constructs a rename command via `.quote_handle(..., purpose = "rename")`
  and executes it with `curl::curl_fetch_memory(sftp_conn$clean_url$full_url, handle = h)`.
- Behavior: if `.recursive = TRUE`, ensures destination parent exists by calling `sftp_mkdir()`.
- URL expectation: relative paths recommended; arguments are validated via `.validate_sftp_url()`.
- Return: `invisible(TRUE)` on success.

## Internal helpers
- `.parse_sftp_url(url)` -> list(protocol, user, hostname, port, path).
  Rejects absolute `//` root-access attempts.
- `.build_sftp_url(protocol, user, hostname, port, path)` -> list(full_url, protocol, user, hostname, port, path) with sanitized values.
- `.validate_sftp_url(sftp_conn, user_url)` -> character `full_url` normalized against `sftp_conn$clean_url`.
- `.sftp_parse(resp, sftp_url, h)` -> parse `ls -l` style bytes into a `data.frame`.

## Tests & expectations
- `tests/testthat/` contains unit tests for `.build_sftp_url()`,
  `.parse_sftp_url()`, `.validate_sftp_url()`, `SFTPConn` creation,
  and an integration-like workflow (upload/list/delete/mkdir/rename).
- Tests assert specific warnings when parsed hostname components overwrite
  function args (e.g., warning when `hostname` includes `:2222` and `port` is also passed).

## Developer checklist & TODOs
- Finish and harden `sftp_download()` (bulk-download mapping,
  clearer distinction between memory vs file downloads, better error messages).
- Add new package imports to `DESCRIPTION::Imports` and run `Rscript -e "renv::snapshot()"`.
- Run `R CMD check .` and fix any issues.
- Regenerate docs with `Rscript -e "devtools::document()"`.

## Suggested minimal PR scope
1. Remove debug breakpoints (if any exist).
2. Tidy `sftp_download()` TODOs and add tests for memory-download mode.
3. Run test suite and fix failing tests.

