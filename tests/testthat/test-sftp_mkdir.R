test_that(
  "SFTP directories can be created in local container",
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

    # create a subdir with existing parent
    sftp_mkdir(
      sftp_conn,
      remote_url = "upload/test_mkdir",
      .recursive = FALSE,
      .verbose = TRUE
    ) |>
      expect_message("mkdir upload/test_mkdir", ignore.case = TRUE) |>
      expect_message("successfully created", ignore.case = TRUE)

    withr::defer(
      sftp_delete(
        sftp_conn,
        remote_url = "sftp://127.0.0.1:2222/upload/test_mkdir",
        .verbose = FALSE,
        .recursive = TRUE
      )
    )

    # create a sbudir with no existing parent
    expect_error(
      sftp_mkdir(
        sftp_conn,
        remote_url = "upload/test_mkdir2/test",
        .recursive = FALSE,
        .verbose = FALSE
      ),
      "Missing parent directory"
    )

    # create a subdir with no existing parent, but use .recursive
    sftp_mkdir(
      sftp_conn,
      remote_url = "upload/test_mkdir2/test/",
      .recursive = TRUE,
      .verbose = TRUE
    ) |>
      expect_message("*mkdir upload", ignore.case = TRUE) |>
      expect_message("successfully created", ignore.case = TRUE) |>
      expect_message("*mkdir upload/test_mkdir2", ignore.case = TRUE) |>
      expect_message("successfully created", ignore.case = TRUE) |>
      expect_message("*mkdir upload/test_mkdir2/test", ignore.case = TRUE) |>
      expect_message("successfully created", ignore.case = TRUE)

    withr::defer(
      sftp_delete(
        sftp_conn,
        remote_url = "sftp://127.0.0.1:2222/upload/test_mkdir2",
        .verbose = FALSE,
        .recursive = TRUE
      )
    )
  }
)
