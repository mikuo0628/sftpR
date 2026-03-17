test_that(
  "SFTP URL building and parsing and warning expectedly",
  {
    expect_equal(
      .build_sftp_url(
        protocol = "sftp://",
        hostname = "127.0.0.1:2222",
        port     = "22",
        .verbose = TRUE
      ),
      list(
        full_url = "sftp://127.0.0.1:2222/",
        protocol = "sftp",
        user     = NULL,
        hostname = "127.0.0.1",
        port     = "2222",
        path     = NULL
      )
    ) |>
      expect_warning(
        "overwriting existing argument `port`",
        ignore.case = TRUE
      )
    expect_equal(
      .build_sftp_url(
        protocol = "sftp://",
        hostname = "127.0.0.1:22/upload/subdir",
        port     = 2222,
        path     = "subdir/test",
        .verbose = TRUE
      ),
      list(
        full_url = "sftp://127.0.0.1:22/upload/subdir",
        protocol = "sftp",
        user     = NULL,
        hostname = "127.0.0.1",
        port = "22",
        path = "upload/subdir"
      )
    ) |>
      expect_warning(
        "overwriting existing argument `port`",
        ignore.case = TRUE
      ) |>
      expect_warning(
        "overwriting existing argument `path`",
        ignore.case = TRUE
      )
    expect_equal(
      .build_sftp_url(
        protocol = "sftp",
        hostname = "sftp://127.0.0.1:22/upload/subdir/",
        port     = 2222,
        path     = "/test",
        .verbose = TRUE
      ),
      list(
        full_url = "sftp://127.0.0.1:22/upload/subdir",
        protocol = "sftp",
        user     = NULL,
        hostname = "127.0.0.1",
        port = "22",
        path = "upload/subdir"
      )
    ) |>
      expect_warning(
        "overwriting existing argument `port`",
        ignore.case = TRUE
      ) |>
      expect_warning(
        "overwriting existing argument `path`",
        ignore.case = TRUE
      )
    expect_equal(
      .build_sftp_url(
        protocol = "sftp",
        hostname = "sftp://user@127.0.0.1:22/upload/subdir/",
        user     = "test",
        port     = 2222,
        path     = "/test",
        .verbose = TRUE
      ),
      list(
        full_url = "sftp://127.0.0.1:22/upload/subdir",
        protocol = "sftp",
        user     = "user",
        hostname = "127.0.0.1",
        port = "22",
        path = "upload/subdir"
      )
    ) |>
      expect_warning(
        "A user name is detected in your hostname that is different",
        ignore.case = TRUE
      ) |>
      expect_warning(
        "overwriting existing argument `user`",
        ignore.case = TRUE
      ) |>
      expect_warning(
        "overwriting existing argument `port`",
        ignore.case = TRUE
      ) |>
      expect_warning(
        "overwriting existing argument `path`",
        ignore.case = TRUE
      )
  }
)
