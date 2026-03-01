test_that(
  "SFTP URLs are validated",
  {
    sftp_conn <-
      sftp_connect$new(
        hostname = "sftp://127.0.0.1:2222/",
        username = "tester",
        password = "password123"
      )
    correct_url <- "sftp://127.0.0.1:2222/upload/mtcars.csv"
    bad_url_1 <- "sftp:/127.0.0.1:2222/upload/mtcars.csv"
    bad_url_2 <- "127.0.0.1:2222/upload/mtcars.csv"
    bad_url_3 <- "127.0.0.1/upload/mtcars.csv"
    bad_url_4 <- "/upload/mtcars.csv"
    bad_url_5 <- "upload/mtcars.csv"
    bad_url_6 <- "//upload/mtcars.csv"
    bad_url_7 <- "sftp://127.0.0.1:2222//upload/mtcars.csv"

    expect_equal(.validate_sftp_url(sftp_conn, bad_url_1), correct_url)
    expect_equal(.validate_sftp_url(sftp_conn, bad_url_2), correct_url)
    expect_equal(.validate_sftp_url(sftp_conn, bad_url_3), correct_url)
    expect_equal(.validate_sftp_url(sftp_conn, bad_url_4), correct_url)
    expect_equal(.validate_sftp_url(sftp_conn, bad_url_5), correct_url)
    expect_equal(.validate_sftp_url(sftp_conn, bad_url_6), correct_url)
    expect_equal(.validate_sftp_url(sftp_conn, bad_url_7), correct_url)
    expect_warning(
      .validate_sftp_url(sftp_conn, bad_url_6),
      "Root access attempt detected",
      ignore.case = TRUE
    )
    expect_warning(
      .validate_sftp_url(sftp_conn, bad_url_7),
      "Root access attempt detected",
      ignore.case = TRUE
    )
  }
)
