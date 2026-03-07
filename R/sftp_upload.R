sftp_upload <- function(
    sftp_conn,
    local_file,
    remote_file = NULL,
    .create_dir = FALSE,
    .verbose = TRUE) {
  # 1) Sanitize and check `remote_file`: should be relative
  remote_file <- 
    .validate_sftp_url(sftp_conn = sftp_conn, remote_file,  .verbose = .verbose)

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

  try_upload <- try(curl::curl_fetch_memory(remote_file, handle = upload_h$h))

  if (inherits(try_upload, "try-error")) {
    stop("!! Upload failed !!: ", conditionMessage(attr(try_upload, "condition")))
  } else {
    .verbose_msg(.verbose = .verbose, "Upload successful!", message)
  }

  return(invisible(TRUE))
}