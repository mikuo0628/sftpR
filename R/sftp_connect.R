#' Creates a list object of connection parameters.
#'
#' @param server single element character vector of server URL or IP address.
#'   Defaults to "localhost". Will clean character of any forward slashes and
#'   replace protocol designation with `protocol`.
#' @param folder single element character vector of the folder sub-path. Can
#'   be multiple sub levels, ie. `dir_1/dir_2/dir_3`. Case-sensitive.
#'   Defaults to `NULL`, which directs to root folder.
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
#' @returns list object of values to be used in other `sftpR` SFTP related
#'   functions.
#' @export
#'
#' @examples
sftp_connect <- function(
    server   = 'localhost',
    folder   = NULL,
    username = NULL,
    password = NULL,
    protocol = 'sftp://',
    port     = 22L,
    timeout  = 30L
) {

  sftp_check <- 'sftp' %in% curl::curl_version()$protocol
  if (isFALSE(sftp_check)) stop('Please check if `curl` contains `sftp` protocol')

  # server name clean up and check
  server <-
    grep(
      x = unlist(strsplit(server, '/')),
      pattern = ':',
      value = T,
      invert = T
    )
  server <- server[server != '']
  server_check <- curl::curl_fetch_memory(server)$status_code == 200
  if (isFALSE(server_check)) stop('The server cannot be found. Please check')

  # folder name clean
  if (!is.null(folder)) {

    folder <- gsub('/+', '/', gsub('^/+|/+$', '', folder))

  }

  # create and configure handle
  h <- curl::new_handle()
  curl::handle_setopt(h, userpwd = paste0(username, ':', password))

  # userpass <- paste0(username, ':', password)

  protocol <- paste0(regmatches(protocol, regexpr('\\w+', protocol)), '://')

  sftp_conn <-
    list(
      url            = paste0(protocol, server),
      url_port       = paste0(protocol, server, ':', port)
      # login_url      = paste0(protocol, userpass, '@', server),
      # login_url_port = paste0(protocol, userpass, '@', server, ':', port)
    )

  if (!is.null(folder) && nchar(folder) != 0) {

    sftp_conn <- lapply(sftp_conn, \(path) file.path(path, folder))

  }

  sftp_conn <-
    append(
      list(
        protocol = protocol,
        server   = server,
        port     = port,
        h        = h,
        # username = username,
        # password = password,
        # userpass = userpass,
        timeout  = timeout
      ),
      sftp_conn
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
      ")"
      # # consume the rest (port, folder path, etc)
      # c(
      #   hostname = ".*$",
      #   folder = "(.*$)"
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
    regexec(paste0(regex_hostname, "(.*$)"), hostname, perl = TRUE)
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
      1
    )

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
