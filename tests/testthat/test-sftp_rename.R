test_that(
  "SFTP renaming works",
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

    sftp_upload(
      sftp_conn   = sftp_conn,
      local_file  = mtcars,
      remote_file = "upload/mtcars.csv",
      .create_dir = FALSE,
      .verbose    = TRUE
    ) |>
      expect_message("uploading", ignore.case = TRUE) |>
      expect_message("upload successful", ignore.case = TRUE) |>
      expect_warning("a data object", ignore.case = TRUE)

    sftp_rename(
      sftp_conn,
      remote_url_from = "sftp://127.0.0.1:2222/upload/mtcars.csv",
      remote_url_to   = "sftp://127.0.0.1:2222/upload/mtcars_2.csv",
    ) |>
      expect_message("rename", ignore.case = TRUE) |>
      expect_message("successfully renamed", ignore.case = TRUE)

    sftp_rename(
      sftp_conn,
      remote_url_from = "sftp://127.0.0.1:2222/upload/mtcars.csv",
      remote_url_to   = "sftp://127.0.0.1:2222/upload/mtcars_2.csv",
    ) |>
      expect_error("does not exist", ignore.case = TRUE)

    sftp_rename(
      sftp_conn,
      remote_url_from = "sftp://127.0.0.1:2222/upload/mtcars_2.csv",
      remote_url_to   = "sftp://127.0.0.1:2222/upload/subdir/mtcars_2.csv",
      .recursive      = FALSE
    ) |>
      expect_message("rename \"upload/mtcars_2.csv\"", ignore.case = TRUE) |>
      expect_error("unable to rename", ignore.case = TRUE)

    sftp_rename(
      sftp_conn,
      remote_url_from = "sftp://127.0.0.1:2222/upload/mtcars_2.csv",
      remote_url_to   = "sftp://127.0.0.1:2222/upload/subdir/mtcars_2.csv",
      .recursive      = TRUE
    ) |>
      expect_message("mkdir upload", ignore.case = TRUE) |>
      expect_message("successfully created", ignore.case = TRUE) |>
      expect_message("mkdir upload/subdir", ignore.case = TRUE) |>
      expect_message("successfully created", ignore.case = TRUE) |>
      expect_message("rename \"upload/mtcars_2.csv\"", ignore.case = TRUE) |>
      expect_message("successfully renamed", ignore.case = TRUE)
  }
)
