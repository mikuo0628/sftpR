#' Download Files from SFTP Server
#'
#' Downloads a file from a remote SFTP server to a local disk location
#' or directly into R's memory as a raw vector.
#'
#' @inheritParams shared_params
#'
#' @param remote_file Character. The path or URL of the file on the SFTP server.
#'
#' @param local_file Character or \code{NULL}.
#'   \itemize{
#'     \item If \code{NA} (default) or an \code{""}: The file is saved to
#'       the current working directory while using \code{remote_file} filename.
#'     \item If \code{character}: The local path where the file should be saved.
#'     \item If \code{NULL}: The file is downloaded to memory and
#'       returned as a \code{raw} vector.
#'   }
#'
#' @param .overwrite Logical. Defaults to \code{FALSE}. If \code{TRUE}, will
#'   overwrite destination file.
#'
#' @param ... Additional arguments passed to \code{curl::curl_download}.
#'
#' @return If \code{local_file} is \code{NULL}, a \code{raw} vector of the file
#'   contents. Otherwise, the resolved local path to the saved file (invisibly).
#'
#' @section Local Path Resolution Caveats:
#'   To provide a "smart" user experience, the function guesses
#'   if \code{local_file} is intended to be a directory or a specific filename:

#' \itemize{
#'   \item \strong{Directory Detection:} If the path exists as a directory, ends
#'     in a trailing slash, or has no file extension, it is treated as a folder.
#'     The \code{remote_file} filename will be appended to this path.
#'   \item \strong{File Detection:} If the path does not exist and contains a
#'     file extension (e.g., ".csv"), it is treated as the final destination
#'     filename.
#'   \item \strong{Ambiguity:} In ambiguous cases (e.g., a non-existent path
#'     without a slash or extension), the function defaults to treating the path
#'     as a directory.
#' }
#'
#' @examples
#' \donttest{
#' # Download and use the remote filename
#' sftp_download(sftp_conn, "data/raw_logs.zip")
#'
#' # Download to a specific local name
#' sftp_download(sftp_conn, "remote_file.csv", "local_name.csv")
#'
#' # Download to memory for immediate processing
#' raw_bytes <- sftp_download(sftp_conn, "data.json", local_file = NULL)
#' data <- jsonlite::fromJSON(rawToChar(raw_bytes))
#' }
#'
#' @export
sftp_download <- function(
    sftp_conn,
    remote_file,
    local_file = NA_character_,
    .create_dir = FALSE,
    .overwrite = FALSE,
    .verbose = TRUE,
    ...) {
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
  filename <- basename(remote_file)
  if (is.na(local_file) || !nzchar(local_file)) {
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
    is_intended_dir <-
      dir.exists(local_file) ||
      grepl("/$", local_file) ||
      !nzchar(tools::file_ext(local_file))

    if (isTRUE(is_intended_dir)) {
      dir_local_file <- local_file
    } else {
      filename       <- basename(local_file)
      dir_local_file <- dirname(local_file)
    }
  }

  dest_file <- file.path(dir_local_file, filename)

  if (!dir.exists(dir_local_file)) {
    if (isTRUE(.create_dir)) {
      dir.create(dir_local_file, recursive = TRUE)
    } else {
      stop(
        sprintf("\nCannot save file here: [%s]", dest_file),
        "\nDirectories may not exist.",
        "\nTry revising `local_file` or setting `.create_dir = TRUE`."
      )
    }
  }

  if (isFALSE(.overwrite) && file.exists(dest_file)) {
    stop(
      "\nFile of the same name already exists.",
      "\nTry setting `.overwrite = TRUE`."
    )
  }
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
