test_that(
  "Files on SFTP can be downloaded in local container",
  {
    # CRAN Requirement: Skip if the resource is unavailable
    skip_if_not(has_test_sftp(), "SFTP Container not reachable")

    # establish connection
    sftp_conn <-
      sftp_connect(
        hostname = "127.0.0.1",
        port     = "2222",
        user     = "tester",
        password = "password123",
        .verbose = FALSE
      )

    temp_local_file <- withr::local_tempfile(fileext = ".csv")

    # upload a file to download
    sftp_upload(
      sftp_conn,
      local_file = mtcars,
      remote_file = "upload/test_download/mtcars.csv",
      .create_dir = TRUE,
      .verbose = FALSE
    )

    # schedule clean up
    withr::defer(
      sftp_delete(
        sftp_conn,
        remote_url = "sftp://127.0.0.1:2222/upload/test_download",
        .verbose = FALSE,
        .recursive = TRUE
      )
    )

    # download to temp file
    expect_message(
      expect_message(
        sftp_download(
          sftp_conn,
          remote_file = "sftp://127.0.0.1:2222/upload/test_download/mtcars.csv",
          local_file = temp_local_file,
          .overwrite = TRUE,
          .verbose = TRUE
        ),
        "downloading",
        ignore.case = TRUE
      ),
      "download successful",
      ignore.case = TRUE
    )

    # by default, do not overwrite
    expect_error(
      sftp_download(
        sftp_conn,
        remote_file = "sftp://127.0.0.1:2222/upload/test_download/mtcars.csv",
        local_file = temp_local_file,
        .overwrite = FALSE,
        .verbose = TRUE
      ),
      "file of the same name already exists",
      ignore.case = TRUE
    )

    # invalid remote_file
    expect_error(
      sftp_download(
        sftp_conn,
        remote_file = "sftp://127.0.0.1:2222/upload/test_download/mtcars2.csv",
        local_file = temp_local_file,
        .overwrite = FALSE,
        .verbose = TRUE
      ),
      "no file exists", ignore.case = TRUE
    )
  }
)
