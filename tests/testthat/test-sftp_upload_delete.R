test_that(
  "Upload and delete all working correctly",
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

    # upload to subdir folder
    remote_path <- "upload/test_upload/mtcars.csv"

    sftp_upload(
      sftp_conn   = sftp_conn,
      local_file  = mtcars,
      remote_file = remote_path,
      .create_dir = TRUE,
      .verbose    = TRUE
    ) |>
      expect_message("Uploading:") |>
      expect_message("Upload successful!") |>
      expect_warning("not a path to a physical file")

    # delete file
    sftp_delete(sftp_conn, remote_path) |>
      expect_message(remote_path) |>
      expect_message("Successfully deleted")

    # no file to delete
    sftp_delete(sftp_conn, remote_path) |>
      expect_message(remote_path) |>
      expect_error("Cannot delete")

    # delete dir
    sftp_delete(sftp_conn, dirname(remote_path)) |>
      expect_message(dirname(remote_path)) |>
      expect_message("Successfully deleted")

    # upload again for .recursive delete
    sftp_upload(
      sftp_conn   = sftp_conn,
      local_file  = mtcars,
      remote_file = remote_path,
      .create_dir = TRUE,
      .verbose    = FALSE
    )

    # no .recursive: cannot delete non-empty folder
    sftp_delete(sftp_conn, dirname(remote_path)) |>
      expect_message(dirname(remote_path)) |>
      expect_error("Cannot delete")

    # .recursive delete of folder and file within
    sftp_delete(sftp_conn, dirname(remote_path), .recursive = TRUE) |>
      expect_message(remote_path) |>
      expect_message("Successfully deleted") |>
      expect_message(dirname(remote_path)) |>
      expect_message("Successfully deleted")
  }
)
