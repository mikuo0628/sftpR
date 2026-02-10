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

#' Build SFTP URL components
#'
#' Helper to construct a full SFTP URL and its components from the given
#' protocol, hostname, port, and folder. Hostname will be sanitized for minor
#' formatting issues; if a port or folder are found inside `hostname` they will
#' override the corresponding arguments.
#'
#' @param protocol single element vector of the protocol designation. Defaults
#'   to `sftp://`.
#' @param hostname single element character vector of hostname URL or IP
#'   address. The function will sanitize `hostname` of minor formatting issues,
#'   such as extra slashes. If a port is included in the `hostname`, it will
#'   override the `port` argument. If a folder path is included in the
#'   `hostname`, it will override the `folder` argument.
#' @param port single element integer vector. Defaults to `22`. Will be
#'   overwritten if a port is present in `hostname`.
#' @param folder single element character vector of the folder sub-path. Can
#'   be multiple sub levels, e.g. `dir_1/dir_2/dir_3`. Case-sensitive.
#'   Defaults to `NULL`, which directs to the root folder. The function will
#'   sanitize `folder` of minor formatting issues, such as extra slashes, and
#'   ensure a trailing slash if not NULL.
#' @return A list with components: full_url, protocol, hostname, port, folder.
#' @keywords internal
build_sftp_url <- function(protocol, hostname, port, folder = NULL) {
  # clean URL components
  regex_hostname <-
    paste0(
      # start of string
      "^",
      # optional non-cap grp matching "sftp://"
      "(?:sftp://)?",
      # optional non-cap grp matching "user@"
      "(?:[^@/]+@)?",
      # main non-cap grp choosing between bracketed IPv6 or normal host
      "(?:",
      # matches [...] (bracketed IPv6)
      "\\[([^\\]]+)\\]",
      "|",
      # capture grp 2 matching hostname or IPv4 (run until `:` or `/` or ws)
      "([^:/\\s]+)",
      ")",
      # optional non-cap grp matching ":port"
      "(?:\\:(\\d+))?"
      # # consume the rest (port, folder path, etc)
      # c(
      #   hostname = ".*$",
      #   folder = "(?:/([^?#]*))?"
      # )
    )

  ## protocol: auto clean up symbols
  protocol <- paste0(regmatches(protocol, regexpr("\\w+", protocol)), "://")
  ## port: overwrite if found in hostname
  regex_port <- regexpr("(?<=:)\\d+", hostname, perl = TRUE)
  if (regex_port[1] != -1) {
    warning(
      paste(
        "'Port' found in hostname.",
        "Overwriting `port` argument with value from `hostname`."
      )
    )
    port <- regmatches(hostname, regex_port)
  }

  ## folder: clean up leading/trailing slashes, replace multiple with single
  regex_folder <-
    regexec(
      paste0(regex_hostname, "(?:/([^?#]*))?$"),
      hostname,
      perl = TRUE
    )
  hostname_folder <- tail(unlist(regmatches(hostname, regex_folder)), 1)
  if (nchar(hostname_folder) > 1) {
    if (!is.null(folder)) {
      warning(
        paste(
          "Folder path found in hostname.",
          "Overwriting `folder` argument with value from `hostname`."
        )
      )
    }
    folder <- hostname_folder
  }
  if (!is.null(folder)) {
    folder <- paste0(gsub("/+", "/", gsub("^/+|/+$", "", folder)), "/")
  }

  ## hostname: account for IPv6, IPv4, forward slashes, protocol, and port
  hostname <-
    tail(
      unlist(
        regmatches(
          hostname,
          regexec(paste0(regex_hostname, ".*$"), hostname, perl = TRUE)
        )
      ),
      2
    )[1]

  return(
    list(
      full_url = paste0(protocol, hostname, ":", port, "/", folder),
      protocol = protocol,
      hostname = hostname,
      port     = port,
      folder   = folder
    )
  )
}
