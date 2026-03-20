test_that(
  "SFTP directories can be created in local container",
  {
    # CRAN Requirement: Skip if the resource is unavailable
    skip_if_not(has_test_sftp(), "SFTP Container not reachable")

    # establish connection
    sftp_conn <- sftp_conn_test()
    base_url <- sprintf("sftp://%s/", paste(get_conn_info(), collapse = ":"))

    # create a subdir with existing parent
    sftp_mkdir(
      sftp_conn,
      remote_url = "upload/test_mkdir",
      .recursive = FALSE,
      .verbose = TRUE
    ) |>
      expect_message("upload/test_mkdir") |>
      expect_message("Successfully created") |>
      expect_warning("do not match.*will be replaced")

    withr::defer(
      sftp_delete(
        sftp_conn,
        remote_url = paste0(base_url, "upload/test_mkdir"),
        .verbose = FALSE,
        .recursive = FALSE
      )
    )

    # create a sbudir with no existing parent
    sftp_mkdir(
      sftp_conn,
      remote_url = "upload/test_mkdir2/test",
      .recursive = FALSE,
      .verbose = FALSE
    ) |>
      expect_error("Missing parent directory")

    # create a subdir with no existing parent, but use .recursive
    sftp_mkdir(
      sftp_conn,
      remote_url = "upload/test_mkdir2/test",
      .recursive = TRUE,
      .verbose = TRUE
    ) |>
      expect_message("\\*mkdir upload") |>
      expect_message("Successfully created") |>
      expect_message("\\*mkdir upload/test_mkdir2") |>
      expect_message("Successfully created") |>
      expect_message("\\*mkdir upload/test_mkdir2/test") |>
      expect_message("Successfully created") |>
      expect_warning("do not match.*will be replaced")

    withr::defer(
      sftp_delete(
        sftp_conn,
        remote_url = paste0(base_url, "upload/test_mkdir2"),
        .verbose = FALSE,
        .recursive = TRUE
      )
    )
  }
)
