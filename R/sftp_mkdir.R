#' @export
sftp_mkdir <- function(
    sftp_conn,
    remote_url = NULL,
    .recursive = TRUE,
    .verbose = TRUE,
    .return_error = !.recursive) {
  # checks remote_url to ensure parts and spelling are consistent with sftp_conn
  remote_url <- .validate_sftp_url(sftp_conn, remote_url, .verbose)

  if (isTRUE(.recursive)) {
    path_string <- gsub("/$", "", .parse_sftp_url(remote_url)$path)
    segments    <- unlist(strsplit(path_string, "/"))
    current_url <- gsub("/$", "", sftp_conn$clean_url$full_url)

    for (segment in segments) {
      # Use the internal non-recursive logic via a recursive call
      # Use .return_error = F to add asterisk (*) before "mkdir" command
      # to ignore error; saves a `.exists` check
      current_url <- paste0(current_url, "/", segment)
      sftp_mkdir(
        sftp_conn,
        remote_url    = current_url,
        .recursive    = FALSE,
        .verbose      = .verbose,
        .return_error = FALSE
      )
    }
  } else {
    # Non-recursive implementation
    h <-
      sftp_conn$.quote_handle(
        remote_url_from = remote_url,
        purpose = "mkdir",
        .verbose = .verbose,
        .return_error = .return_error
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
