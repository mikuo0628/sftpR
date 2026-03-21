#' Determine host and port per environment
get_conn_info <- function() {
  # Priority 1: Use the internal IP if we are in CI
  # Priority 2: Use "sftp" hostname if DNS is working
  # Priority 3: Fallback to localhost for your manual terminal tests
  # host <- Sys.getenv("SFTP_INTERNAL_IP", unset = "sftp")
  host <- "127.0.0.1"

  # If GITHUB_ACTIONS is "true", in the container network
  if (Sys.getenv("ACT") == "true") {
    host <- "sftp"
    port <- "22"
  } else if (Sys.getenv("GITHUB_ACTIONS") == "true") {
    port <- "2223"
  } else {
    # Local manual testing defaults
    port <- "2222"
  }

  return(list(host = host, port = port))
}

#' Check if the SFTP Test Container is reachable
#' @return Logical.
has_test_sftp <- function() {
  # Use a simple socket connection to check the port
  # This is much faster than waiting for a full SFTP timeout
  conn_info <- get_conn_info()
  try_conn <-
    try(
      socketConnection(
        host = conn_info$host,
        port = conn_info$port,
        timeout = 1,
        open = "r"
      ),
      silent = TRUE
    )

  if (inherits(try_conn, "try-error")) {
    return(as.character(try_conn))
  }

  close(try_conn)
  return(TRUE)
}

#' Helps choosing the correct connection parameters depending on the situation
sftp_conn_test <- function(.verbose = FALSE) {
  conn_info <- get_conn_info()
  conn_args <-
    append(
      list(
        hostname = conn_info$host,
        port     = conn_info$port,
        user     = "tester",
        password = "password123",
        .verbose = .verbose
      ),
      list(
        # resolve = sprintf("sftp:%s:%s", conn_info$port, conn_info$host),
        ssh_knownhosts = NULL,
        ssl_verifyhost = 0
      )
      # if (conn_info$host == "127.0.0.1") {
      #   NULL
      #   list(
      #     resolve = sprintf("sftp:%s:%s", conn_info$port, conn_info$host),
      #     ssh_knownhosts = NULL,
      #     ssl_verifyhost = 0
      #   )
      # } else {
      #   NULL
      # }
    )
  return(do.call(sftp_connect, conn_args))
}