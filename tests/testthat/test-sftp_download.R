test_that(
  "multiplication works",
  {
    # clean upload/download
    sapply(
      list.files(
        c("upload", "download"),
        recursive = TRUE,
        include.dirs = TRUE,
        full.name = TRUE
      ),
      unlink,
      recursive = T
    )

    # establish connection
    sftp_conn <-
      sftp_connect(
        hostname = "127.0.0.1",
        port     = "2222",
        user     = "tester",
        password = "password123",
        .verbose = FALSE
      )

    # upload a file to download
    sftp_upload(
      sftp_conn,
      local_file = mtcars,
      remote_file = "upload/test/mtcars.csv",
      .create_dir = T
    )

    sftp_download(
      sftp_conn,
      remote_file = "sftp://127.0.0.1:2222/upload/test/mtcars.csv",
      local_file = "download/mtcars.csv",
      .overwrite = FALSE,
      .verbose = TRUE
    ) |>
      expect_message("downloading", ignore.case = TRUE) |>
      expect_message("download successful", ignore.case = TRUE)

    # Don't overwrite by default
    sftp_download(
      sftp_conn,
      remote_file = "sftp://127.0.0.1:2222/upload/test/mtcars.csv",
      local_file = "download/mtcars.csv",
      .overwrite = FALSE,
      .verbose = TRUE
    ) |>
      expect_error("FIle of the same name already exists", ignore.case = TRUE)

    sftp_download(
      sftp_conn,
      remote_file = "sftp://127.0.0.1:2222/upload/test/mtcars.csv",
      local_file = "download/mtcars.csv",
      .overwrite = TRUE,
      .verbose = TRUE
    ) |>
      expect_message("downloading", ignore.case = TRUE) |>
      expect_message("download successful", ignore.case = TRUE)

    sftp_download(
      sftp_conn,
      remote_file = "sftp://127.0.0.1:2222/upload/test/mtcars.csv",
      local_file = "/download/mtcars.csv",
      .overwrite = TRUE,
      .verbose = TRUE
    ) |>
      expect_error("cannot save file here", ignore.case = TRUE)
  }
)
