#' Delete a file or directory from an SFTP server
#'
#' @description
#' A robust wrapper for removing remote resources. It automatically identifies
#' whether the target is a file or a directory using a "range-probe" heuristic
#' and applies the appropriate protocol command (\code{rm} or \code{rmdir}).
#'
#' @param sftp_conn An \code{SFTPConn} R6 object.
#' @param remote_url Character. The full URL or relative path of the
#'   resource to delete.
#' @param .verbose Logical. Defaults to `TRUE`. Prints helpful messages.
#'
#' @return Logical `TRUE` invisibly, if deletion is successful.
#'
#' @details
#' The function follows a "Secure Pre-flight" workflow:
#' \enumerate{
#'   \item \strong{Validation}: Checks the \code{remote_url} against the
#'         connection's "Source of Truth".
#'   \item \strong{Type Detection}: Uses the internal \code{.fix_url_type}
#'         method (probing \code{range = "0-0"}) to determine if the target
#'         is a file or directory.
#'   \item \strong{Path Normalization}: The \code{.delete_handle} strips the
#'         base URL to ensure the \code{quote} command receives a relative
#'         POSIX path.
#' }
#'
#' Note: Deleting a directory will only succeed if it is completely empty.
#'
#' @export
#' @examples
#' \dontrun{
#' conn <- sftp_connect(hostname = "sftp.example.com", user = "jdoe")
#' sftp_delete(conn, "data/old_file.csv")
#' }
sftp_delete <- function(
    sftp_conn,
    remote_url = NULL,
    .verbose = TRUE) {
  # checks remote_url to ensure parts and spellings are good compare to
  # source of truth
  remote_url <-
    .validate_sftp_url(sftp_conn = sftp_conn, remote_url, .verbose = .verbose)

  # create delete handle that will automatically determine which delete
  # function to use, and removes "base" url from remote_url
  h <- sftp_conn$.delete_handle(remote_url = remote_url, .verbose = .verbose)

  resp <-
    try(
      curl::curl_fetch_memory(sftp_conn$clean_url$full_url, handle = h),
      silent = TRUE
    )

  if (inherits(resp, "try-error")) {
    stop(
      "\nUnable to delete: ", remote_url, "\n",
      "If this is a directory, is it empty?\n",
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
