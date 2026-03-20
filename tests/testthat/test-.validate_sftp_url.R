test_that(
  "Minor SFTP URL issues are fixed",
  {
    # CRAN Requirement: Skip if the resource is unavailable
    skip_if_not(has_test_sftp(), "SFTP Container not reachable")

    # establish connection
    sftp_conn <- sftp_conn_test(.verbose = TRUE)

    base_url <- sprintf("sftp://%s/", paste(get_conn_info(), collapse = ":"))
    relative_url <- "upload/mtcars.csv"
    correct_url <- paste0(base_url, relative_url)

    # fix typo
    .validate_sftp_url(sftp_conn, gsub("\\d+", "1", correct_url)) |>
      expect_equal(correct_url) |>
      expect_warning("replaced")

    # relative path works
    .validate_sftp_url(sftp_conn, paste0("/", relative_url)) |>
      expect_equal(correct_url)

    # relative path works, warning
    .validate_sftp_url(sftp_conn, relative_url) |>
      expect_equal(correct_url) |>
      expect_warning("replaced")

    # replace missing parts
    .validate_sftp_url(sftp_conn, gsub("sftp://", "", correct_url)) |>
      expect_equal(correct_url)

    # replace missing parts
    .validate_sftp_url(sftp_conn, gsub(":\\d+", "", correct_url)) |>
      expect_equal(correct_url)

    # replace incorrect parts
    .validate_sftp_url(sftp_conn, gsub(":\\d+", ":11", correct_url)) |>
      expect_equal(correct_url) |>
      expect_warning("replaced")

    # double slashes fix
    .validate_sftp_url(sftp_conn, paste0("//", relative_url)) |>
      expect_equal(correct_url) |>
      expect_warning("Root access")

    # double slashes fix
    .validate_sftp_url(sftp_conn, gsub(":\\d+", "/", correct_url)) |>
      expect_equal(correct_url) |>
      expect_warning("Root access")

    # double slashes can't fix
    .validate_sftp_url(
      sftp_conn, gsub("(sftp://|:\\d+/)", "//", correct_url)
    ) |>
      expect_error("Absolute paths") |>
      expect_warning("Root access")
  }
)
