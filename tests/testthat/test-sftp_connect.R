test_that(
  "Connection valid",
  {
    # CRAN Requirement: Skip if the resource is unavailable
    skip_if_not(has_test_sftp(), "SFTP Container not reachable")

    # establish connection
    sftp_conn_good <- sftp_conn_test(TRUE)

    expect_true(sftp_conn_good$connection_ok())

    # time out on non-existent host
    sftp_connect(
      hostname = "sftp://2.2.2.2:2222/",
      user     = "tester1",
      password = "password123",
      port     = 2222,
      timeout  = 3L
    ) |>
      expect_error("Cannot connect")

    # detects root slashes
    sftp_connect(
      hostname = "sftp://127.0.0.3:2222//test_dir",
      user     = "tester",
      password = "password123",
      port     = 2222
    ) |>
      expect_error("Absolute paths using `//` are not supported")

    sftp_connect(
      hostname = paste0("tester@", paste(get_conn_info(), collapse = ":")),
      user     = "user",
      port     = "11",
      password = "password123"
    ) |>
      expect_warning("A user name .* different than the `user` arg") |>
      expect_warning("Overwriting existing argument `user`") |>
      expect_warning("Overwriting existing argument `port`")
  }
)
