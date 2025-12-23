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

