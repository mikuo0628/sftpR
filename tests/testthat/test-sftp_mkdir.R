test_that(
  "Creating SFTP directories works",
  {
    # clean upload/
    sapply(
      list.files(
        "upload",
        recursive = TRUE,
        include.dirs = TRUE,
        full.name = TRUE
      ),
      unlink,
      recursive = TRUE
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

    sftp_mkdir(
      sftp_conn,
      remote_url = "upload/subdir",
      .recursive = FALSE,
      .verbose = TRUE
    ) |>
      expect_message("mkdir upload/subdir", ignore.case = TRUE) |>
      expect_message("successfully created", ignore.case = TRUE)

    sftp_mkdir(
      sftp_conn,
      remote_url = "upload/subdir2/test",
      .recursive = FALSE,
      .verbose = TRUE
    ) |>
      expect_message("mkdir upload/subdir2/test", ignore.case = TRUE) |>
      expect_error("missing parent directory", ignore.case = TRUE)

    sftp_mkdir(
      sftp_conn,
      remote_url = "upload/subdir2/test/",
      .recursive = TRUE,
      .verbose = TRUE
    ) |>
      expect_message("successfully created", ignore.case = TRUE) |>
      expect_message("*mkdir upload", ignore.case = TRUE) |>
      expect_message("successfully created", ignore.case = TRUE) |>
      expect_message("*mkdir upload/subdir2", ignore.case = TRUE) |>
      expect_message("successfully created", ignore.case = TRUE) |>
      expect_message("*mkdir upload/subdir2/test", ignore.case = TRUE)

    sftp_mkdir(
      sftp_conn,
      remote_url = "upload/subdir2/test/",
      .recursive = TRUE,
      .verbose = TRUE
    ) |>
      expect_message("successfully created", ignore.case = TRUE) |>
      expect_message("*mkdir upload", ignore.case = TRUE) |>
      expect_message("successfully created", ignore.case = TRUE) |>
      expect_message("*mkdir upload/subdir2", ignore.case = TRUE) |>
      expect_message("successfully created", ignore.case = TRUE) |>
      expect_message("*mkdir upload/subdir2/test", ignore.case = TRUE)

  }
)
