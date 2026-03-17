#' Download Files from SFTP Server
#'
#' Downloads a file from a remote SFTP server either to a local disk location
#' or directly into R's memory as a raw vector.
#'
#' @param sftp_conn An \code{SFTPConn} R6 object, created by
#'   \code{\link{sftp_connect}}.
#' @param remote_file Character. The path or URL of the file on the SFTP server.
#' @param local_file Character or \code{NULL}.
#'   \itemize{
#'     \item If \code{character}: The local path where the file should be saved.
#'       If only a directory is provided, the remote filename is used.
#'     \item If \code{NA} (default) or an empty string: The file is saved to the
#'       current working directory using its remote filename.
#'     \item If \code{NULL}: The file is downloaded to memory and
#'       returned as a \code{raw} vector.
#'   }
#' @param .create_dir Logical. If \code{TRUE}, creates the local destination
#'   directory if it does not exist. Defaults to \code{FALSE}.
#' @param .verbose Logical. If \code{TRUE}, prints progress and status messages.
#' @param ... Additional arguments passed to \code{curl::curl_download}.
#'
#' @return If \code{local_file} is \code{NULL}, a \code{raw} vector of the file
#'   contents. Otherwise, the path to the saved file (invisibly).
#'
#' @details
#' The function uses \code{curl::curl_fetch_memory} for memory downloads and
#' \code{curl::curl_download} for disk downloads to ensure efficient stream
#' handling. If \code{.create_dir = FALSE} and the local directory is missing,
#' the function will stop with an error.
#'
#' @examples
#' \dontrun{
#' # Download to current working directory
#' sftp_download(sftp_conn, "data/raw_logs.zip")
#'
#' # Download to memory and convert a text file
#' raw_bytes <- sftp_download(sftp_conn, "config.txt", local_file = NULL)
#' cat(rawToChar(raw_bytes))
#'
#' # Download to a specific path, creating folders if needed
#' sftp_download(
#'   sftp_conn,
#'   "report.pdf",
#'   "exports/2026/final_report.pdf",
#'   .create_dir = TRUE
#' )
#' }
#'
#' @export
sftp_download <- function(
    sftp_conn,
    remote_file,
    local_file = NA_character_,
    .create_dir = FALSE,
    .verbose = TRUE,
    ...) {
  browser()
  # 1) Sanitize remote url
  remote_file <-
    .validate_sftp_url(sftp_conn, sftp_conn$.fix_url_type(remote_file))

  if (!sftp_conn$.exists(remote_file)) {
    stop("\nNo file exists in the provided `remote_file` URL")
  }

  # 2) Check where to handle download
  # if `local_file` is NULL, assume user wants to load to memory.
  # this would be raw vector, and there are several ways of handling this.
  # TODO: consider building raw vector handling

  ## To memory
  if (is.null(local_file)) {
    .verbose_msg(.verbose = .verbose, "Downloading to memory...\n", message)
    resp <- curl::curl_fetch_memory(remote_file, handle = sftp_conn$h)
    return(resp$content)
  }

  ## To file
  if (is.na(local_file) || !nzchar(local_file)) {
    filename <- basename(remote_file)
    dir_local_file <- getwd()
    .verbose_msg(
      .verbose = .verbose,
      sprintf(
        paste(
          "A destination `local_file` has not been provided.",
          "\nWorking directory will be used: \"%s\""
        ),
        local_file
      ),
      message
    )
  } else {
    # handle whether
    ## local_file exists, is file
    ## local_file exists, is dir
    ## local_file does not exist, would be file
    ## local_file does not exist, would be dir
    utils::file_test(dirname(local_file))


    filename <- basename(local_file)
    dir_local_file <- dirname(local_file)
  }

  if (!dir.exists(dir_local_file)) {
    if (isTRUE(.create_dir)) {
      dir.create(dir_local_file, recursive = TRUE)
    } else {
      stop(
        "\nCannot save file: directories do not exist.",
        "\nTry setting `.create_dir = TRUE`."
      )
    }
  }

  dest_file <- file.path(dir_local_file, filename)
  .verbose_msg(
    .verbose = .verbose,
    sprintf(
      "\nDownloading: \n[%s] ===> [%s]\n",
      remote_file, dest_file
    ),
    message
  )

  try_download <-
    try(
      curl::curl_download(
        url      = remote_file,
        destfile = dest_file,
        quiet    = !.verbose,
        handle   = sftp_conn$h,
        ...
      )
    )

  if (inherits(try_download, "try-error")) {
    stop(
      "\nCannot download: ",
      conditionMessage(attr(try_download, "condition"))
    )
  } else {
    .verbose_msg(.verbose = .verbose, "Download successful!", message)
  }

  return(invisible(dest_file))
}
