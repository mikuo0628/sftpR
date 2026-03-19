test_that(
  "Connection valid",
  {
    expect_warning(
      sftp_conn_good <-
        sftp_connect(
          hostname = "sftp://127.0.0.1:2222/",
          user     = "tester",
          password = "password123",
          .verbose = TRUE
        ),
      "overwriting existing argument `port`",
      ignore.case = TRUE
    )
    expect_true(sftp_conn_good$connection_ok())
    expect_equal(sftp_conn_good$clean_url$port, "2222")

    expect_error(
      sftp_connect(
        hostname = "sftp://127.0.0.1:2222/",
        user     = "tester1",
        password = "password123",
        port     = 2222
      ),
      "Please check your connection settings and credentials.",
      ignore.case = TRUE
    )
    expect_error(
      sftp_connect(
        hostname = "sftp://127.0.0.1:2222//test_dir",
        user     = "tester",
        password = "password123",
        port     = 2222
      ),
      "Absolute paths using `//` are not supported",
      ignore.case = TRUE
    )
    sftp_connect(
      hostname = "sftp://tester@127.0.0.1:2222",
      user     = "user",
      password = "password123"
    ) |>
      expect_warning(
        "it is more preferrable to use the `user` argument", ignore.case = TRUE
      ) |>
      expect_warning(
        "overwriting existing argument `user`", ignore.case = TRUE
      ) |>
      expect_warning(
        "overwriting existing argument `port`", ignore.case = TRUE
      )
  }
)
