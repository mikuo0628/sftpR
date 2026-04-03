#' Rename or Move Remote SFTP Resources
#'
#' Renames a file or directory on the SFTP server. This can also be used to
#' move files between directories.
#'
#' @inheritParams shared_params
#'
#' @param remote_url_from Character. The current path of the file or directory.
#'
#' @param remote_url_to Character. The new path for the file or directory.
#'
#' @return \code{invisible(TRUE)} on success.
#'
#' @details
#' The SFTP protocol's \code{rename} command is typically non-overwriting. If
#' \code{remote_url_to} already exists, the operation will fail.
#'
#' When \code{.recursive = TRUE}, parent directories of \code{remote_url_to}
#' are identified, and existence ensured before attempting the renaming.
#'
#' @examples
#' \donttest{
#' # Simple rename in the same folder
#' sftp_rename(sftp_conn, "old_name.csv", "new_name.csv")
#'
#' # Move a file to a new, potentially non-existent directory
#' sftp_rename(
#'   sftp_conn,
#'   "data/raw.csv",
#'   "archive/2026/processed.csv",
#'   .recursive = TRUE
#' )
#' }
#'
#' @export
sftp_rename <- function(
    sftp_conn,
    remote_url_from = NULL,
    remote_url_to = NULL,
    .recursive = FALSE,
    .verbose = TRUE) {
  # checks remote_url to ensure parts and spelling are consistent with sftp_conn
  remote_url <-
    lapply(
      list(
        remote_url_from = remote_url_from,
        remote_url_to   = remote_url_to
      ),
      \(x) .validate_sftp_url(sftp_conn, x, .verbose)
    )

  if (!isTRUE(sftp_conn$.exists(remote_url$remote_url_from))) {
    stop("What you are trying to rename does not exist.", call. = FALSE)
  }

  if (isTRUE(.recursive)) {
    sftp_mkdir(
      sftp_conn,
      remote_url =
        paste0(
          sftp_conn$clean_url$full_url,
          dirname(.parse_sftp_url(remote_url$remote_url_to)$path)
        ),
      .recursive = .recursive,
      .verbose = .verbose,
      .ignore_error = TRUE
    )
  }

  h <-
    do.call(
      sftp_conn$.quote_handle,
      append(
        remote_url,
        list(
          purpose = "rename",
          .verbose = .verbose
        )
      )
    )

  resp <-
    try(
      # does not overwrite if target exists: SSH_FX_FILE_ALREADY_EXISTS
      curl::curl_fetch_memory(sftp_conn$clean_url$full_url, handle = h),
      silent = TRUE
    )

  if (inherits(resp, "try-error")) {
    err_msg <- conditionMessage(attr(resp, "condition"))
    stop(
      "\nCannot rename:\n",
      ifelse(
        grepl("No such file", err_msg) && !.recursive,
        paste0(
          "`remote_url_to` may already exist, or ",
          "missing one or more of its parent directories.\n",
          "Try setting `.recursive = TRUE`."
        ),
        err_msg
      ),
      call. = FALSE
    )
  }

  .verbose_msg(
    .verbose = .verbose,
    sprintf(
      "Successfully renamed: %s ---> %s",
      remote_url$remote_url_from, remote_url$remote_url_to
    ),
    message
  )

  return(invisible(TRUE))
}
