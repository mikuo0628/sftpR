.verbose_msg <- function(verbose = FALSE, msg = "") {
  if (isTRUE(verbose)) { message(msg) }
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
