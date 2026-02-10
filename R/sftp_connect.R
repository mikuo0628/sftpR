#' Creates a list object of connection parameters.
#'
#' This function creates a list object of connection parameters,
#' including an SFTP handle, to be used in other `sftpR` SFTP related functions.
#' It will also check if the `hostname` is valid and can be found,
#' and will warn if a port or folder path is included in the `hostname`
#' and override the corresponding arguments.
#' The function will sanitize the `hostname` and `folder` of minor
#' formatting issues, such as extra slashes.
#'
#' @param hostname single element character vector of hostname URL or
#'   IP address. Defaults to "localhost". The funciton will sanitize
#'   `hostname` of minor formatting issues, such as extra slashes.
#'   If a port is included in the `hostname`, it will warn and override
#'   the `port` argument.
#'   If a folder path is included in the `hostname`, it will warn and override
#'   the `folder` argument.
#' @param folder single element character vector of the folder sub-path. Can
#'   be multiple sub levels, ie. `dir_1/dir_2/dir_3`. Case-sensitive.
#'   Defaults to `NULL`, which directs to root folder.
#'   The function will sanitize `folder` of minor formatting issues,
#'   such as extra slashes.
#' @param username single element character vector of SFTP account name.
#'   Recommend using `keyring`package or system variables to manage.
#'   Defaults to `NULL`.
#' @param password single element character vector of SFTP password
#'   associate with the `username`. Recommend using `keyring` package or
#'   system variable to manage. Defaults to `NULL`.
#'   NOTE: Your password should not contain `@` or `:` as they are reserved
#'   for URL processing.
#' @param protocol single element vector of the protocol designation. Defaults
#'   to `sftp://`.
#' @param port single element integer vector. Defaults to `22`.
#' @param timeout single element integer vector. `curl` connection timeout value
#'   in seconds. Defaults to `30`.
#'
#' @returns list object of values and handle, to be used in other `sftpR`
#'   SFTP related functions.
#' @export
#'
#' @examples
#' \dontrun{
#' # Quick connectivity test
#' # Establish a connection
#' conn <- sftp_connect(
#'   hostname = "sftp://127.0.0.1:2222/upload",
#'   user = "tester",
#'   password = "password123",
#'   timeout = 30,
#'   .verbose = TRUE
#' )
#' }
#' @export
sftp_connect <- function(
    hostname = "localhost",
    folder = NULL,
    username = NULL,
    password = NULL,
    protocol = "sftp://",
    port = 22L,
    timeout = 30L,
    .verbose = FALSE) {
  # check protocol "sftp"
  sftp_check <- "sftp" %in% curl::curl_version()$protocol
  if (isFALSE(sftp_check)) {
    stop("Please check if `curl` contains `sftp` protocol")
  }

  # create and configure handle
  h <- curl::new_handle()
  curl::handle_setopt(
    h,
    userpwd = paste0(username, ":", password),
    ssh_auth_types = 2,
    verbose = .verbose
  )

  url_components <- build_sftp_url(protocol, hostname, port, folder)

  hostname_check <-
    try(
      silent = TRUE,
      curl::curl_fetch_memory(url_components$full_url, handle = h)
    )

  if (inherits(hostname_check, "try-error")) {
    stop("The hostname cannot be found. Please check")
  }

  sftp_conn <-
    append(
      url_components,
      list(
        h        = h,
        timeout  = timeout
      )
    )

  return(sftp_conn)
}
