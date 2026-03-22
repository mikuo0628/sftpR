#' Delete Files or Directories from SFTP Server
#'
#' Deletes a specific file or directory from the remote server. If the target
#' is a directory, it must be empty unless \code{.recursive = TRUE}
#' is specified.
#'
#' @inheritParams sftp_conn_generator
#'
#' @param sftp_conn An \code{SFTPConn} R6 object, created by
#'   \code{\link{sftp_connect}}.
#'
#' @param remote_url Character. The full URL or path of the file or directory to
#'   be deleted.
#'
#' @param .recursive Logical. If \code{TRUE}, will recursively list and delete
#'   all contents within a directory before deleting the directory itself.
#'   Defaults to \code{FALSE}.
#'
#' @param .validate Logical. Whether to validate the \code{remote_url} against
#'   the connection object. Internally set to \code{FALSE} during recursive
#'   calls to improve performance.
#'
#' @return \code{TRUE} (invisibly) if the operation was successful.
#'
#' @section Safety Warnings:
#' \itemize{
#'   \item \strong{Irreversibility:} Deletion on SFTP is permanent. There is no
#'     "Trash" or "Recycle Bin" on most SFTP server configurations.
#'   \item \strong{Recursive Caution:} Setting \code{.recursive = TRUE} on a
#'     high-level directory can result in significant data loss. Always verify
#'     the \code{remote_url} before executing.
#' }
#'
#' @examples
#' \dontrun{
#' # Delete a single file
#' sftp_delete(sftp_conn, "project/old_report.csv")
#'
#' # Delete an entire directory and its contents
#' sftp_delete(sftp_conn, "project/temp_outputs/", .recursive = TRUE)
#' }
#'
#' @export
sftp_delete <- function(
    sftp_conn,
    remote_url = NULL,
    .recursive = FALSE,
    .verbose = TRUE,
    .validate = TRUE) {
  # checks remote_url to ensure parts and spelling are consistent with sftp_conn
  # if .recursive, URL should be good to go and no need to validate
  if (isTRUE(.validate)) {
    remote_url <- .validate_sftp_url(sftp_conn, remote_url, .verbose)
  }

  if (isTRUE(.recursive)) {
    df_list <-
      sftp_list(sftp_conn, sftp_url = remote_url, .recursive = .recursive)
    urls <- rev(sort(unique(c(remote_url, paste0(df_list$url, df_list$name)))))
    for (current_url in urls) {
      sftp_delete(
        sftp_conn,
        remote_url = current_url,
        .recursive = FALSE,
        .verbose   = .verbose,
        .validate  = FALSE
      )
    }
  } else {
    # Non-recursive implementation
    # create delete handle that will automatically determine which delete
    # function to use, and removes "base" url from remote_url
    h <-
      sftp_conn$.quote_handle(
        remote_url_from = remote_url,
        purpose         = "rm",
        .verbose        = .verbose
      )
    resp <-
      try(
        curl::curl_fetch_memory(sftp_conn$clean_url$full_url, handle = h),
        silent = TRUE
      )

    if (inherits(resp, "try-error") && !.recursive) {
      stop(
        "\nCannot delete: ", remote_url,
        "\nIf this is a directory, is it empty? ",
        "Try setting `.recursive = TRUE`.",
        "\nIf this is a file, are you sure it still exists?\n",
        conditionMessage(attr(resp, "condition")),
        call. = FALSE
      )
    }

    .verbose_msg(
      .verbose = .verbose,
      sprintf("Successfully deleted: %s", remote_url),
      message
    )
    return(invisible(TRUE))
  }
}
