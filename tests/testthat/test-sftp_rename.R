test_that(
  "Renaming SFTP objects works",
  {
    # CRAN Requirement: Skip if the resource is unavailable
    skip_if_not(has_test_sftp(), "SFTP Container not reachable")

    # establish connection
    sftp_conn <- sftp_conn_test()

    base_url <- sprintf("sftp://%s/", paste(get_conn_info(), collapse = ":"))

    # create a file to rename
    sftp_upload(
      sftp_conn   = sftp_conn,
      local_file  = mtcars,
      remote_file = "upload/test_rename/mtcars.csv",
      .create_dir = TRUE,
      .verbose    = FALSE
    )

    # rename that file at the same level
    sftp_rename(
      sftp_conn,
      remote_url_from = "upload/test_rename/mtcars.csv",
      remote_url_to   = "upload/test_rename/mtcars_2.csv",
    ) |>
      expect_message("rename") |>
      expect_message("Successfully renamed") |>
      expect_warning("do not match.*will be replaced") |>
      expect_warning("do not match.*will be replaced")

    # file no longer there to be renamed
    sftp_rename(
      sftp_conn,
      remote_url_from = "upload/test_rename/mtcars.csv",
      remote_url_to   = "upload/test_rename/mtcars_2.csv",
    ) |>
      expect_error("does not exist") |>
      expect_warning("do not match.*will be replaced") |>
      expect_warning("do not match.*will be replaced")

    # rename file to a different level, without .recursive
    sftp_rename(
      sftp_conn,
      remote_url_from = "upload/test_rename/mtcars_2.csv",
      remote_url_to   = "upload/test_rename2/mtcars.csv",
      .recursive      = FALSE
    ) |>
      expect_message("rename \"upload/test_rename/mtcars_2.csv\"") |>
      expect_error("Cannot rename") |>
      expect_warning("do not match.*will be replaced") |>
      expect_warning("do not match.*will be replaced")

    # rename file to a different level, with .recursive
    sftp_rename(
      sftp_conn,
      remote_url_from = "upload/test_rename/mtcars_2.csv",
      remote_url_to   = "upload/test_rename2/mtcars.csv",
      .recursive      = TRUE
    ) |>
      expect_message("*mkdir upload") |>
      expect_message("Successfully created") |>
      expect_message("*mkdir upload/test_rename2") |>
      expect_message("Successfully created") |>
      expect_message("rename \"upload/test_rename/mtcars_2.csv\"") |>
      expect_message("Successfully renamed") |>
      expect_warning("do not match.*will be replaced") |>
      expect_warning("do not match.*will be replaced")

    # rename folder
    sftp_rename(
      sftp_conn,
      remote_url_from = "upload/test_rename",
      remote_url_to   = "upload/test_rename3"
    ) |>
      expect_message("rename \"upload/test_rename\"") |>
      expect_message("Successfully renamed") |>
      expect_warning("do not match.*will be replaced") |>
      expect_warning("do not match.*will be replaced")

    # schedule clean up
    withr::defer({
      sftp_delete(
        sftp_conn,
        "upload/test_rename2",
        .recursive = TRUE,
        .verbose = FALSE
      )
      sftp_delete(
        sftp_conn,
        "upload/test_rename3",
        .recursive = TRUE,
        .verbose = FALSE
      )
    })
  }
)
