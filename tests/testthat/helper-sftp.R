#' Check if the SFTP Test Container is reachable
#' @return Logical.
has_test_sftp <- function() {
  # Use a simple socket connection to check the port
  # This is much faster than waiting for a full SFTP timeout
  try_conn <-
    try(
      socketConnection(
        host = "127.0.0.1",
        port = 2222,
        timeout = 1,
        open = "r"
      ),
      silent = TRUE
    )

  if (inherits(try_conn, "try-error")) {
    return(FALSE)
  }

  close(try_conn)
  return(TRUE)
}
