<!-- Brief, targeted instructions for AI coding agents working on this repo -->
# sftpR — AI Coding Instructions

This repository is an R package providing small helpers for SFTP operations. Use these notes to be immediately productive and avoid common pitfalls.

- Project layout: package root contains `DESCRIPTION`, `NAMESPACE`, `sftpR.Rproj`; implementation is in `R/`; user docs in `man/`; package-managed environment under `renv/`.

- Key patterns and examples (look at the listed files):
  - Connection builder: `R/sftp_connect.R` — returns an `sftp_conn` list that includes a curl handle (`sftp_conn$h`) and `url`/`url_port` strings. Example call: `sftp_connect(hostname='sftp://127.0.0.1/', folder='upload', username='user', password='pw', port=2222)`.
  - Upload: `R/sftp_upload.R` — uses `get_sftp_handle()` and `.build_sftp_url(protocol, server, remote_path)` then `curl::curl_upload()`; note `curl::handle_setopt(..., ftp_create_missing_dirs = 1)` is used to allow recursive directory creation.
  - Download: `R/sftp_download.R` — accepts `sftp_conn` and uses `sftp_conn$h` with `curl::curl_download()`; it also uses `sftp_list()` to enumerate remote files.
  - URL helper: `R/sftp_connect.R` defines `.build_sftp_url()` — prefer using it to construct server URLs consistently.

- Important runtime / dependency notes:
  - The package relies on the system `curl` with SFTP support; code checks `curl::curl_version()$protocol` for `sftp` in `R/sftp_connect.R`. Ensure test/dev machines have libcurl built with SFTP.
  - The project uses `renv/`. Recreate environment with `Rscript -e "renv::restore()"` before running or testing code.

- Developer workflows (concrete commands):
  - Restore environment: `Rscript -e "renv::restore()"`
  - Update roxygen docs: `Rscript -e "devtools::document()"` (or `Rscript -e "roxygen2::roxygenize()"`) — do not edit files in `man/` directly.
  - Build: `R CMD build .`
  - Check: `R CMD check .` or `Rscript -e "devtools::check()"` — ensure no `browser()` calls or embedded credentials remain.

- Project-specific conventions and gotchas:
  - Do not commit credentials. Many example calls in `R/` contain placeholders; when running examples use `keyring::key_get()` or environment variables as suggested in `R/sftp_connect.R`.
  - The codebase still contains `browser()` calls in `R/sftp_connect.R` and `R/sftp_download.R`. Remove these debug breakpoints before creating PRs or running checks.
  - Functions commonly accept and pass an `sftp_conn` list; use `sftp_conn$h` for curl operations and `sftp_conn$url`/`url_port` for string formatting.
  - Add any new package dependency to `DESCRIPTION::Imports` and run `Rscript -e "renv::snapshot()"` to capture it.

- PR checklist for humans and agents:
  - Remove `browser()` and other interactive debug calls.
  - Update roxygen docs and regenerate `man/` with `devtools::document()`.
  - Run `R CMD check .` and resolve issues.
  - Keep secrets out of the repo; prefer `keyring` or env vars.

If anything here looks incomplete or you want more specifics (tests, CI, or an example workflow script), tell me which area to expand.
