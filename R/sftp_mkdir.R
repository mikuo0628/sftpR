#' @export
sftp_mkdir <- function(
    sftp_conn,
    remote_url = NULL,
    .recursive = TRUE,
    .verbose   = TRUE) {
  # checks remote_url to ensure parts and spelling are consistent with sftp_conn
  remote_url <- .validate_sftp_url(sftp_conn, remote_url, .verbose)
  remote_url <-
    ifelse(!grepl("/$", remote_url), paste0(remote_url, "/"), remote_url)

  h <-
    sftp_conn$.quote_handle(
      remote_url_from = remote_url,
      purpose = "mkdir",
      .recursive = .recursive,
      .verbose = .verbose
    )

  resp <-
    try(
      curl::curl_fetch_memory(sftp_conn$clean_url$full_url, handle = h),
      silent = TRUE
    )

  if (inherits(resp, "try-error")) {
    err_msg <- conditionMessage(attr(resp, "condition"))
    stop(
      "\nUnable to create directory: ", remote_url, "\n",
      ifelse(
        grepl("No such file", err_msg),
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
