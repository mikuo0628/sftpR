.verbose_msg <- function(.verbose = FALSE, msg = "", type = message) {
  if (!isTRUE(.verbose)) return(invisible(NULL))
  type <- as.character(substitute(type))
  switch(
    type,
    "warning" = warning(msg, call. = FALSE),
    "stop"    = stop(msg, call. = FALSE),
    message(msg)
  )
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
.build_sftp_url <- function(protocol, hostname, port, folder = NULL) {
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

  full_url <-
    .url_path_join(
      base_url = paste0(protocol, hostname, ":", port),
      folder,
      is_dir = !is.null(folder)
    )

  return(
    list(
      full_url = full_url,
      protocol = protocol,
      hostname = hostname,
      port     = port,
      folder   = folder
    )
  )
}

#' Join URL components safely
#'
#' @description
#' Internal helper to join a base URL and a subdirectory without
#' doubling slashes or losing the protocol.
#'
#' @param base_url The base SFTP string (e.g., "sftp://host").
#' @param ... Additional path components to append.
#' @param is_dir Logical. If TRUE, ensures a trailing slash.
#' @keywords internal
.url_path_join <- function(base_url, ..., is_dir = TRUE) {
  # 1. Clean the base URL of any trailing slashes
  url <- gsub("/+$", "", base_url)

  # 2. Process and clean all subcomponents
  components <- rlang::list2(...)
  components <- unlist(lapply(components, function(x) {
    if (is.null(x) || x == "") {
      return(NULL)
    }
    # Remove leading and trailing slashes from parts
    gsub("^/|/$", "", x)
  }))

  # 3. Join with single slashes
  if (length(components) > 0) {
    url <- paste(c(url, components), collapse = "/")
  }

  # 4. Enforce trailing slash for directories (Required for SFTP listing)
  if (is_dir && !grepl("/$", url)) {
    url <- paste0(url, "/")
  }

  return(url)
}

#' Validate and Sanitize SFTP URLs against a Connection Object
#'
#' This internal utility ensures that a user-provided URL matches the
#' "Source of Truth" defined in an [SFTPConn] object. It prevents common
#' formatting errors, warns against security-risky root access attempts
#' (double slashes), and corrects any incongruities in the protocol,
#' hostname, or port.
#'
#' @param sftp_conn An `R6` object of class `SFTPConn`.
#' @param user_url
#'   Character string. The destination SFTP URL or path provided by the user.
#'
#' @details
#' The function performs the following steps:
#' \itemize{
#'   \item Checks for empty inputs.
#'   \item Detects and "heals" double-slash root access attempts
#'         (e.g., `sftp://host//path` becomes `sftp://host/path`).
#'   \item Deconstructs the URL using regular expressions to compare its
#'         components against the `sftp_conn` settings.
#'   \item Issues a warning if the user-provided protocol, hostname, or
#'         port differs from the established connection.
#'   \item Reconstructs a clean, standardized URL.
#' }
#'
#' @return A sanitized character string containing the validated SFTP URL.
#'
#' @keywords internal
#' @noRd
.validate_sftp_url <- function(sftp_conn, user_url) {
  if (is.null(user_url) || user_url == "") {
    stop("SFTP URL cannot be empty.")
  }
  # Check for Double-Slash (Root Access) Attempt
  # In curl, sftp://host//path indicates root. We check for // after
  # the authority or at start.
  if (grepl("://[^/]*//", user_url) || grepl("^//", user_url)) {
    .verbose_msg(
      .verbose = TRUE,
      paste(
        "Root access attempt detected (//).",
        "SFTP paths should be relative to your home directory for security.",
        "Converting to relative path."
      ),
      warning
    )
    # This regex finds '://', matches the host/port [^/]+,
    # then replaces the following '//' with a single '/'
    user_url <- gsub("(://[^/]+)//", "\\1/", user_url)
    # Also handle the case if the user started the string with //
    # (e.g. "//upload/file.csv")
    user_url <- gsub("^//", "/", user_url)
  }

  # Extract parts from user_input to check for incongruence
  pattern <- "^(?:([a-z]+:/{1,2}))?([^:/]+)?(?::([0-9]+))?(/.*)?$"
  matches <- regexec(pattern, user_url, perl = TRUE)
  # If empty, will return "" empty string, not NA
  parts <-
    setNames(
      regmatches(user_url, matches)[[1]][-1],
      c("protocol", "hostname", "port", "folder")
    )
  checks <- parts[-length(parts)] == sftp_conn$clean_url[2:4]

  if (isTRUE(all(checks))) {
    return(user_url)
  }

  # If mismatching sftp_conn$clean_url, print warning
  .verbose_msg(
    .verbose = sftp_conn$.verbose,
    sprintf(
      paste(
        "\nThe following parts of the provided SFTP URL do not match the",
        "connection:\n%s\n",
        "\nThey will be replaced by the respective parts in `sftp_conn`."
      ),
      paste("  -", names(which(checks == FALSE)), collapse = "\n")
    ),
    warning
  )

  # Replace the mismatched with the appropriate valuess from sftp_conn$clean_url
  for (part in names(which(checks == FALSE))) {
    parts[part] <- sftp_conn$clean_url[[part]]
  }

  user_url <-
    paste0(
      parts["protocol"],
      parts["hostname"],
      paste0(":", parts["port"]),
      "/",
      gsub("^/|/$", "", parts["folder"], perl = TRUE)
    )

  return(user_url)
}
