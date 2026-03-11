#' List and Crawl SFTP Directory Contents
#'
#' Retrieves a directory listing from an SFTP server. If
#' \code{.recursive = TRUE}, it will perform a depth-first crawl of all
#' subdirectories found, implementing a path-tracking
#' algorithm to detect and skip circular symbolic links, preventing
#' infinite recursion and stack overflow errors.
#'
#' @param sftp_conn A \code{SFTPConn} object containing connection details and
#'   authentication. Created by \code{\link{sftp_connect}}.
#'
#' @param sftp_url A SFTP URL of which the contents will be listed. If `NULL`,
#'   the base URL in \code{SFTPConn} will be used: contents of the SFTP home
#'   folder will be listed.
#'
#' @param .recursive Logical. If \code{TRUE}, recursively enters subdirectories
#'   to return a flattened tree of all remote objects. Defaults to \code{FALSE}.
#'
#' @param .check Logical. If \code{TRUE}, determines \code{sftp_url} is a
#'   directory or a file, and modify the URL appropriately if needed.
#'   Defaults to value of \code{.recursive}.
#'
#' @return A \code{data.frame} containing remote file/directory metadata:
#' \itemize{
#'   \item \code{permission}: Unix-style permission string (e.g., "drwxr-xr-x").
#'   \item \code{nlink}: Number of hard links.
#'   \item \code{user}: Owner username.
#'   \item \code{group}: Owner group.
#'   \item \code{size}: File size in bytes.
#'   \item \code{month, day, time_year}: Timestamp components.
#'   \item \code{name}: File or directory name.
#'   \item \code{type}: Categorization as "dir" or "file".
#'   \item \code{url}: The source URL for that specific object.
#' }
#'
#' @export
#' @examples
sftp_list <- function(
    sftp_conn = NULL,
    sftp_url = NULL,
    .verbose = TRUE,
    .recursive = FALSE,
    .check = .recursive) {
  sftp_url <-
    if (is.null(sftp_url)) {
      sftp_conn$clean_url$full_url
    } else {
      # Sanitize `sftp_url`
      sftp_conn$.__enclos_env__$private$.fix_url_type(
        .validate_sftp_url(sftp_conn, sftp_url, .verbose = .verbose)
      )
    }

  resp <-
    try(
      curl::curl_fetch_memory(sftp_url, sftp_conn$h)
    )

  if (resp$status_code != 0 || inherits(resp, "try-error")) {
    stop("SFTP connection issue")
  }

  df_objs <- .sftp_parse(resp, h = sftp_conn$h)

  # recursively crawl subdirectories
  if (isTRUE(.recursive)) {
    sftp_crawl <- function(df_objs, visited = character()) {
      if (all(df_objs$type == "file")) return(df_objs)

      df_output <- data.frame()

      for (df_row in split(df_objs, seq_len(nrow(df_objs)))) {
        df_output <- rbind(df_output, df_row)
        if (df_row$type == "dir") {
          # build URL to be checked
          target_url <-
            paste0(gsub("/$", "", df_row$url), "/", df_row$name, "/")
          # safety check to avoid circular symbolic link
          if (target_url %in% visited) {
            warning("Circular link detected. Skipping: ", target_url)
            next
          }

          new_visited <- c(visited, target_url)

          df_objs_sub <- .sftp_parse(sftp_url = target_url, h = sftp_conn$h)

          df_output <-
            rbind(
              df_output,
              sftp_crawl(df_objs_sub, visited = new_visited)
            )
        }
      }

      return(df_output)
    }

    df_objs <- sftp_crawl(df_objs, visited = sftp_conn$clean_url$full_url)
  }

  # ls -l follows specific Unix convention:
  # if `time_year` shows `HH:MM`, assume year == last 6 months, even if
  # crossing over to previous year.
  # if `time_year` shows `YYYY`, assume older than last 6 months.
  return(df_objs)
}

#' Parse SFTP Directory Listings into Data Frames
#'
#' @description
#' A utility function that converts the raw binary content of an SFTP directory
#' listing (returned by \code{curl}) into a structured R \code{data.frame}.
#'
#' @param resp A response list from \code{curl::curl_fetch_memory}.
#'   If \code{NULL}, the function will attempt to fetch data using
#'   \code{sftp_url} and \code{h}.
#'
#' @param sftp_url Character. The SFTP URL to fetch if \code{resp} is
#'   \code{NULL}. This function will assume URL is valid (ie. dir or file).
#'
#' @param h A \code{curl} handle. Required only if \code{resp} is \code{NULL}.
#'
#' @return A \code{data.frame} with parsed Unix-style directory metadata,
#'   or \code{NULL} if the directory is empty.
#'
#' @details
#' The function automatically filters out the special Unix directory entries
#' \code{"."} and \code{".."}. It determines object types based on the first
#' character of the permission string (e.g., 'd' for directory).
#' @keywords internal
#' @noRd
.sftp_parse <- function(resp = NULL, sftp_url = NULL, h = NULL) {
  if (is.null(resp)) {
    if (is.null(sftp_url)) stop("Must supply either `resp` or `sftp_url`")
    resp <- do.call(curl::curl_fetch_memory, list(url = sftp_url, h = h))
  } else {
    sftp_url <- resp$url
  }

  # parse `ls -l` style output into df
  df_objs <-
    data.frame(
      read.table(
        text = unlist(strsplit(rawToChar(resp$content), "\n")),
        sep = "",
        fill = TRUE,
        col.names =
          c(
            "permission", "nlink", "user", "group", "size",
            "month", "day", "time_year",
            "name"
          )
      )
    )

  # remove special directory entries
  df_objs <- subset(df_objs, !name %in% c(".", ".."))

  # handle type
  df_objs$type <-
    sapply(
      substr(df_objs$permission, 1, 1),
      \(x) switch(x,
        "d" = "dir",
        "-" = "file"
      ),
      simplify = TRUE
    )

  if (nrow(df_objs) == 0) {
    return(NULL)
  }

  df_objs$url <- sftp_url

  return(df_objs)
}
