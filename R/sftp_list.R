#' List and Crawl SFTP Directory Contents
#'
#' Retrieves a directory listing from an SFTP server. If
#' \code{.recursive = TRUE}, it will perform a depth-first crawl of all
#' subdirectories found, implementing a path-tracking
#' algorithm to detect and skip circular symbolic links, preventing
#' infinite recursion and stack overflow errors.
#'
#' @param sftp_conn A \code{SFTPConn} object containing connection details and
#' authentication. Created by \code{\link{sftp_connect}}.
#'
#' @param .recursive Logical. If \code{TRUE}, recursively enters subdirectories
#'   to return a flattened tree of all remote objects. Defaults to \code{FALSE}.
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
    .recursive = FALSE) {
  # get response
  resp <-
    try(
      curl::curl_fetch_memory(sftp_conn$clean_url$full_url, sftp_conn$h)
    )

  if (resp$status_code != 0 || inherits(resp, "try-error")) {
    stop("SFTP connection issue")
  }

  df_objs <- sftp_parse(resp)

  # recursively crawl subdirectories
  if (isTRUE(.recursive)) {
    sftp_crawl <- function(df_objs, visited = character()) {
      if (all(df_objs$type == "file")) {
        return(df_objs)
      }

      df_output <- data.frame()

      for (df_row in split(df_objs, 1:nrow(df_objs))) {
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

          df_objs_sub <-
            sftp_parse(
              sftp_url = df_row$url,
              subdir   = df_row$name,
              h        = sftp_conn$h
            )

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
#' @param resp A response list from \code{curl::curl_fetch_memory}. If \code{NULL},
#'   the function will attempt to fetch data using \code{sftp_url} and \code{h}.
#' @param sftp_url Character. The SFTP URL to fetch if \code{resp} is \code{NULL}.
#' @param subdir Character. An optional subdirectory to append to \code{sftp_url}.
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
sftp_parse <- function(
    resp = NULL,
    sftp_url = NULL,
    subdir = NULL,
    h = NULL) {
  if (is.null(resp)) {
    if (is.null(sftp_url)) stop("Must supply either `resp` or `sftp_url`")
    url <- .url_path_join(sftp_url, subdir, is_dir = !is.null(subdir))
    resp <- do.call(curl::curl_fetch_memory, list(url = url, h = h))
  } else {
    url <- resp$url
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
      simplify = T
    )

  if (nrow(df_objs) == 0) {
    return(NULL)
  }

  df_objs$url <- url

  return(df_objs)
}
