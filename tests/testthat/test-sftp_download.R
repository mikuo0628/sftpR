test_that(
  "Files on SFTP can be downloaded in local container",
  {
    # testthat::skip("Temporarily disabled for debugging")
    # CRAN Requirement: Skip if the resource is unavailable
    skip_if_not(has_test_sftp(), "SFTP Container not reachable")

    # establish connection
    sftp_conn <- sftp_conn_test()

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
        remote_url = "upload/test_download",
        .verbose = FALSE,
        .recursive = TRUE
      )
    )

    # download to temp file
    sftp_download(
      sftp_conn,
      remote_file = "upload/test_download/mtcars.csv",
      local_file = temp_local_file,
      .overwrite = TRUE,
      .verbose = TRUE
    ) |>
      expect_message("Downloading") |>
      expect_message("Download successful")

    # by default, do not overwrite
    sftp_download(
      sftp_conn,
      remote_file = "upload/test_download/mtcars.csv",
      local_file = temp_local_file,
      .overwrite = FALSE,
      .verbose = TRUE
    ) |>
      expect_error("File of the same name already exists")

    # invalid remote_file
    sftp_download(
      sftp_conn,
      remote_file = "upload/test_download/mtcars2.csv",
      local_file = temp_local_file,
      .overwrite = FALSE,
      .verbose = TRUE
    ) |>
      expect_error("No file exists")
  }
)
