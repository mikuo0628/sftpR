sftp_upload <- function(
    sftp_conn,
    local_file,
    remote_file = NULL,
    .create_dir = FALSE,
    .verbose = TRUE) {
  on.exit(close(upload_h$file_con), add = TRUE)
  on.exit(
    if (is.null(!(upload_h$tempfile))) unlink(upload_h$tempfile),
    add = TRUE
  )
  browser()
  # 0) 
  sftp_conn$clean_url
  # 1) Sanitize and check `remote_file`: should be relative
  file.path(
    sftp_conn$clean_url$full_url,
    remote_file
  )

  gsub("(.*://)", "", "sftp://127.0.0.1", perl = TRUE)

  # 2) create upload handle
  # - this step creates curl handle specifically for upload
  # - and checks local file
  sftp_list(sftp_conn, .recursive = TRUE)
  upload_h <-
    sftp_conn$.upload_handle(
      local_file = local_file, reuse = TRUE,
      ftp_create_missing_dirs = ifelse(isTRUE(.create_dir), 1L, 0L)
    )

  try_upload <-
    try(
      curl::curl_fetch_memory(
        "sftp://127.0.0.1:2222/upload/subdir/sub2/mtcars3.csv",
        handle = upload_h$h
      )
    )

  grep("Remote file not found", try_upload[[1]])
  if (inherits(try_upload, "try-error")) {
    stop("Upload failed: ", conditionMessage(attr(try_upload, "condition")))
  } else {
    message("Upload successful!")
  }
}

# sftp_upload(
#   sftp_conn =
#     sftp_connect$new(
#       hostname = "sftp://127.0.0.1:2222/",
#       username = "tester",
#       password = "password123"
#     ),
#   local_file = mtcars,
#   remote_file = "upload/mtcars.csv",
#   .verbose = TRUE
# )
