#' Upload a file to an SFTP server
#'
#' @description
#' A robust wrapper to upload local files or data frames to a remote SFTP
#' server. It manages the libcurl handle lifecycle, ensures connections are
#' closed, and validates URLs against the connection's "Source of Truth".
#'
#' @param sftp_conn An \code{SFTPConn} R6 object, created by
#'   \code{sftp_connect}.
#'
#' @param local_file Character string (path to a file) or a \code{data.frame}.
#'   Data frames are automatically written to a temp file before upload.
#'   The temp file will automatically be cleaned up at the end of function.
#'
#' @param remote_file Character string. The destination path on the server.
#'   If \code{NULL}, attempts to use the basename of the `local_file`.
#'
#' @param .create_dir Logical. If \code{TRUE}, recursively creates missing
#'   remote directories in the path (\code{CURLOPT_FTP_CREATE_MISSING_DIRS}).
#'
#' @param .verbose Logical. Defaults to `TRUE`. Prints helpful messages.
#'
#' @return
#'   Returns \code{TRUE} (invisibly) on success. Throws an error on failure.
#'
#' @details
#' The function uses a secure lifecycle:
#' \enumerate{
#'   \item Validates the remote URL to prevent credential leakage.
#'   \item Opens a file connection to the local source.
#'   \item Uses \code{on.exit} to ensure file handles are released and
#'         temporary files are unlinked even if the transfer is interrupted.
#' }
#'
#' @export
#' @examples
#' \dontrun{
#' conn <- sftp_connect(hostname = "sftp.example.com", user = "user")
#' sftp_upload(conn, my_df, "uploads/data.csv")
#' }
sftp_upload <- function(
    sftp_conn,
    local_file,
    remote_file = NULL,
    .create_dir = FALSE,
    .verbose = TRUE) {
  # 1) Sanitize and check `remote_file`: should be relative
  if (is.null(remote_file)) remote_file <- basename(match.call()$local_file)
  remote_file <-
    .validate_sftp_url(sftp_conn = sftp_conn, remote_file, .verbose = .verbose)

  # 2) create upload handle
  # - this step creates curl handle specifically for upload
  # - and checks local file
  upload_h <-
    sftp_conn$.upload_handle(
      local_file = local_file,
      reuse = TRUE,
      ftp_create_missing_dirs = ifelse(isTRUE(.create_dir), 1L, 0L),
      .verbose = .verbose
    )

  on.exit(close(upload_h$file_con), add = TRUE)
  on.exit(
    if (!is.null(upload_h$tempfile)) unlink(upload_h$tempfile),
    add = TRUE
  )

  .verbose_msg(
    .verbose = .verbose,
    sprintf(
      "\nUploading: \n[%s] ===> [%s]\n",
      upload_h$tempfile, remote_file
    ),
    message
  )

  try_upload <-
    try(
      curl::curl_fetch_memory(remote_file, handle = upload_h$h),
      silent = TRUE
    )

  if (inherits(try_upload, "try-error")) {
    stop(
      "\nCannot upload: ",
      conditionMessage(attr(try_upload, "condition")),
      "\nTry setting `.create_dir = TRUE`."
    )
  } else {
    .verbose_msg(.verbose = .verbose, "Upload successful!", message)
  }

  return(invisible(TRUE))
}
