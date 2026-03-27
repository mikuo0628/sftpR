#' @keywords internal
#' @noRd
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

#' Parse and Validate SFTP URL Components
#'
#' Internal utility to deconstruct an SFTP URL into its constituent parts
#' (protocol, user, hostname, port, and path). It enforces security by
#' disallowing absolute paths (indicated by double slashes) and performs
#' basic sanitization.
#'
#' @inheritParams sftp_connect
#'
#' @param url A character string containing the SFTP URL.
#'
#' @return A named list containing:
#'   \item{protocol}{The scheme (e.g., "sftp").}
#'   \item{user}{The username if provided (e.g., "john").}
#'   \item{hostname}{The server address (IPv4, IPv6, or domain).}
#'   \item{port}{The port number as a string.}
#'   \item{path}{The file or directory path relative to the home directory.}
#'
#' @details
#' The function uses a single-pass regular expression to extract components.
#' It specifically blocks "Root Access" attempts (e.g., `sftp://host//etc`)
#' by checking if the captured path starts with a forward slash.
#'
#' @keywords internal
.parse_sftp_url <- function(url, .verbose = TRUE) {
  pattern <-
    paste0(
      # group 0) protocol, "optional" non capturing group
      # starts with at least one lowercase
      # alpha, followed by : and at least 0 and at most 2 forward slahses,
      # just in case typo.
      "^(?:([a-z]+):/{1,2})?",
      # "^([a-z]+:/{1,2})?", # with ://
      # group 1) user, "optional" NCG
      "(?:([^@/]+)@)?",
      # group 2) host, "optional", IPv6 in [] or hostname/IPv4
      "(\\[[^\\]]+\\]|[^:/\\s]+)?",
      # group 3) port, "optional" NCG starts with : followed by digits
      "(?::(\\d+))?",
      # group 4) path, "optional" capturing group starts with a forward slash
      # after host/port
      "(?:/(/?.*))?$"
    )

  matches <- regexec(pattern, url, perl = TRUE)

  # If empty, will return "" empty string, not NA
  parts <-
    stats::setNames(
      regmatches(url, matches)[[1]][-1],
      c("protocol", "user", "hostname", "port", "path")
    )

  # if (nzchar(parts[["protocol"]]) && grepl(":/?$", parts[["protocol"]])) {
  #   .verbose_msg(
  #     .verbose = .verbose,
  #     "Missing slashes will be added to `protocol`.",
  #     warning
  #   )
  # }

  if (isTRUE(grepl("^/|//", parts[["path"]]))) {
    stop("Absolute paths using `//` are not supported.")
  }

  if (nzchar(parts[["user"]]) && grepl(":", parts[["user"]])) {
    .verbose_msg(
      .verbose = .verbose,
      paste(
        "Credentials detected in URL.",
        "It is safer to use SSH keys or a keyring."
      ),
      warning
    )
  }

  return(as.list(parts))
}

#' Build SFTP URL components
#'
#' Helper (stateless) function to construct a full SFTP URL and
#' its components from the given protocol, hostname, port, and path
#' Hostname will be sanitized for minor formatting issues;
#' if a port or path are found inside `hostname` they will
#' override the corresponding arguments.
#'
#' @inheritParams shared_params
#'
#' @return A list with components: full_url, protocol, hostname, port, path.
#'
#' @keywords internal
.build_sftp_url <- function(
    protocol = "sftp",
    user = NULL,
    hostname = NULL,
    port = "22",
    path = NULL,
    .verbose = TRUE) {
  ## list arg values
  list_args <- as.list(environment())

  ## protocol: remove up symbols
  list_args$protocol <-
    regmatches(list_args$protocol, regexpr("\\w+", list_args$protocol))

  ## extract URL components
  list_parsed <- .parse_sftp_url(hostname)

  ## list_args[[part]] = "",  list_parse[[part]] = "",  do nothing
  ## list_args[[part]] = "x", list_parse[[part]] = "",  do nothing
  ## list_args[[part]] = "x", list_parse[[part]] = "x", do nothing
  ## list_args[[part]] = "",  list_parse[[part]] = "x", replace arg, warn
  ## list_args[[part]] = "x", list_parse[[part]] = "y", replace arg, warn

  for (part in names(list_parsed[nzchar(list_parsed)])) {
    if (isTRUE(list_parsed[[part]] != list_args[[part]])) {
      if (part == "user") {
        .verbose_msg(
          .verbose = .verbose,
          sprintf(
            paste(
              "A user name is detected in your hostname",
              "that is different than the `user` argument.",
              "\nIt is more preferrable to use the `user` argument over",
              "\"user@hostname\" format."
            )
          ),
          warning
        )
      }
      .verbose_msg(
        .verbose = ifelse(part == "hostname", FALSE, .verbose),
        sprintf(
          paste0(
            "`%s` found in argument `hostname`. ",
            "Overwriting existing argument `%s` value: \"%s\" -> \"%s\""
          ),
          part, part, list_args[[part]], list_parsed[[part]]
        ),
        warning
      )
    }
    # assign(x = part, value = list_parsed[[part]])
    list_args[[part]] <- list_parsed[[part]]
  }

  list_args <-
    lapply(
      list_args,
      FUN = \(x) if (is.null(x)) NULL else gsub("^\\W+|\\W+$", "", x)
    )

  full_url <-
    paste0(
      list_args$protocol, "://",
      # if (!is.null(list_args$user)) paste0(list_args$user, "@") else NULL,
      list_args$hostname,
      if (!is.null(list_args$port)) paste0(":", list_args$port) else NULL,
      "/",
      list_args$path
    )

  return(
    lapply(
      append(
        list(
          full_url = full_url
        ),
        list_args
      ),
      FUN = function(x) {
        if (is.null(x)) {
          return(NULL)
        } else {
          return(as.character(x))
        }
      }
    )
  )
}

#' Validate and Sanitize SFTP URLs against a Connection Object
#'
#' This internal utility ensures that a user-provided URL matches the
#' "Source of Truth" defined in an \code{SFTPConn} object.
#' It prevents common formatting errors, warns against security-risky
#' root access attempts (double slashes), and corrects any incongruities
#' in the protocol, hostname, or port.
#'
#' @inheritParams shared_params
#'
#' @param user_url Character string. The destination SFTP URL or
#'   path provided by the user.
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
.validate_sftp_url <- function(
    sftp_conn,
    user_url,
    .verbose = sftp_conn$.verbose) {
  if (is.null(user_url) || user_url == "") {
    stop("SFTP URL cannot be empty.")
  }

  # Check for Double-Slash (Root Access) Attempt
  # In curl, sftp://host//path indicates root. Check for // after
  # the authority or at start.
  if (grepl("://[^/]*//", user_url) || grepl("^//", user_url)) {
    .verbose_msg(
      .verbose = .verbose,
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
  parts <- .parse_sftp_url(user_url)
  hostname_confirmed <- nzchar(parts["protocol"]) || nzchar(parts["port"])
  hostname_matched <- parts["hostname"] == sftp_conn$clean_url$hostname

  if (!hostname_confirmed && !hostname_matched) parts["path"] <- user_url

  # If parts are empty, replace with sftp_conn, silently
  for (part in names(parts[which(!nzchar(parts))])) {
    parts[[part]] <- sftp_conn$clean_url[[part]]
  }

  checks <-
    unlist(parts[c("protocol", "hostname", "port")]) ==
      unlist(sftp_conn$clean_url[c("protocol", "hostname", "port")])

  if (!isTRUE(all(checks))) {
    # Replace the mismatched with the appropriate valuess
    # from sftp_conn$clean_url, print warning
    incorrect_parts <- names(which(checks == FALSE))
    .verbose_msg(
      .verbose = .verbose,
      sprintf(
        paste(
          "\nThe following parts parsed form the provided SFTP URL",
          "do not match the `SFTPConn` connection,",
          "and will be replaced:\n%s\n"
        ),
        paste0(
          "  - ", incorrect_parts, ": ",
          sprintf(
            "\"%s\" ===> \"%s\"",
            parts[incorrect_parts],
            sftp_conn$clean_url[incorrect_parts]
          ),
          collapse = "\n"
        )
      ),
      warning
    )

    parts[incorrect_parts] <- sftp_conn$clean_url[incorrect_parts]
  }

  user_url <-
    do.call(.build_sftp_url, parts[-which(names(parts) == "user")])$full_url

  return(user_url)
}
