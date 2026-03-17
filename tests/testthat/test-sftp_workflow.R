test_that(
  "Upload, delete, and list all working correctly",
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

    # 1) testing upload, one directory level
    file_remote_path_1 <-
      paste0(sftp_conn$clean_url$full_url, "upload/mtcars.csv")

    expect_false(sftp_conn$.exists(file_remote_path_1))

    sftp_upload(
      sftp_conn   = sftp_conn,
      local_file  = mtcars,
      remote_file = "upload/mtcars.csv",
      .create_dir = FALSE,
      .verbose    = TRUE
    ) |>
      expect_message(file_remote_path_1) |>
      expect_message("Upload successful!") |>
      expect_warning("not a path to a physical file", ignore.case = TRUE)

    expect_true(sftp_conn$.exists(file_remote_path_1))

    file_remote_path_2 <-
      gsub("mtcars.csv", "mtcars_2.csv", file_remote_path_1)

    sftp_rename(
      sftp_conn,
      remote_url_from = file_remote_path_1,
      remote_url_to = file_remote_path_2,
      .recursive = FALSE,
      .verbose = TRUE
    ) |>
      expect_message("rename \"upload/mtcars.csv\" \"upload/mtcars_2.csv\"") |>
      expect_message("successfully renamed", ignore.case = T)

    sftp_rename(
      sftp_conn,
      remote_url_from = file_remote_path_1,
      remote_url_to = file_remote_path_2,
      .recursive = FALSE,
      .verbose = TRUE
    ) |>
      expect_message("rename \"upload/mtcars.csv\" \"upload/mtcars_2.csv\"") |>
      expect_error("Cannot rename", ignore.case = TRUE)

    expect_true(sftp_delete(sftp_conn, file_remote_path_1)) |>
      expect_message("successfully deleted", ignore.case = TRUE) |>
      expect_message("rm upload/mtcars.csv", ignore.case = TRUE)

    expect_true(sftp_delete(sftp_conn, file_remote_path_1)) |>
      expect_message("rm upload/mtcars.csv", ignore.case = TRUE) |>
      expect_error("Cannot delete", ignore.case = TRUE)

    expect_true(sftp_delete(sftp_conn, file_remote_path_2)) |>
      expect_message("successfully deleted", ignore.case = TRUE) |>
      expect_message("rm upload/mtcars_2.csv", ignore.case = TRUE)

    # 2) testing upload, two directory levels, recursive create folder
    file_remote_path_3 <-
      paste0(sftp_conn$clean_url$full_url, "upload/subdir/mtcars.csv")

    expect_false(sftp_conn$.exists(file_remote_path_3))

    sftp_upload(
      sftp_conn   = sftp_conn,
      local_file  = mtcars,
      remote_file = "upload/subdir/mtcars.csv",
      .create_dir = FALSE,
      .verbose    = TRUE
    ) |>
      expect_error("upload failed", ignore.case = TRUE) |>
      expect_message(file_remote_path_3) |>
      expect_warning("data object, not a path", ignore.case = TRUE)

    sftp_upload(
      sftp_conn   = sftp_conn,
      local_file  = mtcars,
      remote_file = "upload/subdir/mtcars.csv",
      .create_dir = TRUE,
      .verbose    = TRUE
    ) |>
      expect_message(file_remote_path) |>
      expect_message("Upload successful!") |>
      expect_warning("not a path to a physical file", ignore.case = TRUE)

    expect_true(sftp_conn$.exists(file_remote_path))

    sftp_delete(sftp_conn, dirname(file_remote_path)) |>
      expect_error("Cannot delete", ignore.case = TRUE) |>
      expect_message("rmdir upload/subdir", ignore.case = TRUE)

    sftp_list(sftp_conn, .recursive = T)

    file_remote_path_4 <-
      gsub("subdir", "subdir/subdir2", file_remote_path_3)

    sftp_rename(
      sftp_conn,
      remote_url_from = file_remote_path_3,
      remote_url_to = file_remote_path_4,
      .recursive = FALSE,
      .verbose = TRUE
    )
    expect_true(sftp_delete(sftp_conn, file_remote_path)) |>
      expect_message("successfully deleted", ignore.case = TRUE) |>
      expect_message("rm upload/subdir/mtcars.csv", ignore.case = TRUE)

    expect_true(sftp_delete(sftp_conn, dirname(file_remote_path))) |>
      expect_message("successfully deleted", ignore.case = TRUE) |>
      expect_message("rmdir upload/subdir", ignore.case = TRUE)

    sftp_list(sftp_conn, .recursive = T)

    # 3) testing mkdir
    sftp_mkdir(sftp_conn, "upload/subdir")
  }
)
