test_that(
  "SFTP URL parsed correctly",
  {
    expect_equal(
      .parse_sftp_url("sftp://user@hostname:10/test"),
      list(
        protocol = "sftp",
        user     = "user",
        hostname = "hostname",
        port     = "10",
        path     = "test"
      )
    )
    expect_equal(
      .parse_sftp_url("sftp://hostname:10/test"),
      list(
        protocol = "sftp",
        user     = "",
        hostname = "hostname",
        port     = "10",
        path     = "test"
      )
    )
    expect_equal(
      .parse_sftp_url("sftp://test:123/etc/config/"),
      list(
        protocol = "sftp",
        user     = "",
        hostname = "test",
        port     = "123",
        path     = "etc/config/"
      )
    )
    expect_equal(
      .parse_sftp_url("[2000:db8::1]:2222"),
      list(
        protocol = "",
        user     = "",
        hostname = "[2000:db8::1]",
        port     = "2222",
        path     = ""
      )
    )
    expect_equal(
      .parse_sftp_url("john_doe@sftp.example.com"),
      list(
        protocol = "",
        user     = "john_doe",
        hostname = "sftp.example.com",
        port     = "",
        path     = ""
      )
    )
    expect_equal(
      .parse_sftp_url("my-storage-cluster"),
      list(
        protocol = "",
        user     = "",
        hostname = "my-storage-cluster",
        port     = "",
        path     = ""
      )
    )
    expect_equal(
      .parse_sftp_url("hostname"),
      list(
        protocol = "",
        user     = "",
        hostname = "hostname",
        port     = "",
        path     = ""
      )
    )
    expect_error(
      .parse_sftp_url("sftp://example.com//etc/config"),
      "absolute paths using `//` are not supported", ignore.case = TRUE
    )
    expect_error(
      .parse_sftp_url("sftp://host:21/folder_name//test/file.csv?temp=true"),
      "absolute paths using `//` are not supported", ignore.case = TRUE
    )
  }
)
