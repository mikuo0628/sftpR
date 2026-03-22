#' Create Remote Directories via SFTP
#'
#' This function creates directories on a remote server using the SFTP protocol.
#' It supports recursive directory creation, effectively behaving like
#' \code{mkdir -p} on a Unix-like system.
#'
#' @inheritParams sftp_conn_generator
#'
#' @param sftp_conn An \code{SFTPConn} R6 object, created by
#'   \code{\link{sftp_connect}}.
#'
#' @param remote_url Character. The relative or absolute path of the directory
#'   to create.
#'
#' @param .recursive Logical. If \code{TRUE}, creates missing parent
#'   directories. Defaults to \code{TRUE}.
#'
#' @param .ignore_error Logical. If \code{FALSE}, the function uses the \code{*}
#'   prefix in the curl quote command to ignore errors (e.g., if the directory
#'   already exists). Defaults to \code{!.recursive}.
#'
#' @return \code{invisible(TRUE)} on success.
#'
#' @details
#' When \code{.recursive = TRUE}, the function splits the path into segments and
#' attempts to create each one sequentially. It uses the \code{*} prefix for
#' internal calls to ensure that existing directories do not trigger errors.
#'
#' @examples
#' \dontrun{
#' # Create a nested directory structure
#' sftp_mkdir(sftp_conn, "project/data/results/2026", .recursive = TRUE)
#'
#' # Create a single directory and fail if parents are missing
#' sftp_mkdir(sftp_conn, "simple_dir", .recursive = FALSE)
#' }
#'
#' @export
sftp_mkdir <- function(
    sftp_conn,
    remote_url = NULL,
    .recursive = TRUE,
    .verbose = TRUE,
    .ignore_error = .recursive) {
  # checks remote_url to ensure parts and spelling are consistent with sftp_conn
  remote_url <- .validate_sftp_url(sftp_conn, remote_url, .verbose)

  if (isTRUE(.recursive)) {
    path_string <- gsub("/$", "", .parse_sftp_url(remote_url)$path)
    segments <- unlist(strsplit(path_string, "/"))
    current_url <- gsub("/$", "", sftp_conn$clean_url$full_url)

    for (segment in segments) {
      # Use the internal non-recursive logic via a recursive call
      # Use .ignore_error = T to add asterisk (*) before "mkdir" command
      # to ignore error; saves a `.exists` check
      current_url <- paste0(current_url, "/", segment)
      sftp_mkdir(
        sftp_conn,
        remote_url    = current_url,
        .recursive    = FALSE,
        .verbose      = .verbose,
        .ignore_error = TRUE
      )
    }
  } else {
    # Non-recursive implementation
    h <-
      sftp_conn$.quote_handle(
        remote_url_from = remote_url,
        purpose = "mkdir",
        .verbose = .verbose,
        .ignore_error = .ignore_error
      )

    resp <-
      try(
        curl::curl_fetch_memory(sftp_conn$clean_url$full_url, handle = h),
        silent = TRUE
      )

    if (inherits(resp, "try-error")) {
      err_msg <- conditionMessage(attr(resp, "condition"))
      stop(
        "\nCannot create directory: ", remote_url, "\n",
        ifelse(
          grepl("No such file", err_msg) && !.recursive,
          paste0(
            "Missing parent directory:\n",
            "Try setting `.recursive = TRUE`.\n"
          ),
          err_msg
        ),
        call. = FALSE
      )
    }

    .verbose_msg(
      .verbose = .verbose,
      sprintf("Successfully created directory: %s", remote_url),
      message
    )
    return(invisible(TRUE))
  }
}
