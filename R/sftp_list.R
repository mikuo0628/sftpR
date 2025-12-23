
#' Title
#'
#' @param sftp_conn
#' @param .recursive
#'
#' @returns
#' @export
#'
#' @examples
sftp_list <- function(
    sftp_conn  = NULL,
    .recursive = F
) {

  # get response
  resp <- try(curl::curl_fetch_memory(sftp_conn$url, sftp_conn$h))

  if (resp$status_code != 0) stop('SFTP connection issue')

  df_objs <- sftp_parse(resp)

  if (isTRUE(.recursive)) {

    sftp_crawl <- function(df_objs) {

      if (all(df_objs$type == 'file')) return(df_objs)

      df_output <- data.frame()

      for (df_row in split(df_objs, 1:nrow(df_objs))) {

        df_output <- rbind(df_output, df_row)

        if (df_row$type == 'dir') {

          df_objs <-
            sftp_parse(
              sftp_url = df_row$url,
              subdir   = df_row$name,
              h        = sftp_conn$h
            )

          df_output <-
            rbind(
              df_output,
              sftp_crawl(df_objs)
            )

        }

      }

      return(df_output)

    }

    df_objs <- sftp_crawl(df_objs)

  }

  # ls -l follows specific Unix convention:
  # if `time_year` shows `HH:MM`, assume year == last 6 months, even if
  # crossing over to previous year.
  # if `time_year` shows `YYYY`, assume older than last 6 months.

  return(df_objs)

}

#' Title
#'
#' @param resp
#' @param sftp_url
#' @param subdir
#' @param h
#'
#' @returns
#'
#' @examples
sftp_parse <- function(
    resp     = NULL,
    sftp_url = NULL,
    subdir   = NULL,
    h        = NULL
) {
  if (is.null(resp)) {

    if (is.null(sftp_url)) stop('Must supply either `response` list or SFTP URL')

    url <-
      do.call(
        file.path,
        append(
          Filter(
            Negate(is.null),
            list(sftp_url = gsub('/$', '', sftp_url), subdir = subdir)
          ),
          list('/')
        )
      )

    resp <- do.call(curl::curl_fetch_memory, list(url = url, h = h))

  } else {

    url <- resp$url

  }

  # parse `ls -l` style output into df
  df_objs <-
    data.frame(
      read.table(
        text = unlist(strsplit(rawToChar(resp$content), '\n')),
        sep = '',
        fill = T,
        col.names =
          c(
            'permission', 'nlink', 'user', 'group', 'size',
            'month', 'day', 'time_year',
            'name'
          )
      )
    )

  # remove special directory entries
  df_objs <- subset(df_objs, !name %in% c('.', '..'))

  # handle type
  df_objs$type <-
    sapply(
      substr(df_objs$permission, 1, 1),
      \(x) switch(x, 'd' = 'dir', '-' = 'file'),
      simplify = T
    )

  if (nrow(df_objs) == 0) return(NULL)

  df_objs$url <- url

  return(df_objs)

}

# sftp_list(
#   sftp_connect(
#     server   = 'sftp://sftp.phsa.ca/',
#     # folder   = '/////test///test////',
#     # username = 'SVC_BCCDCAnalytics',
#     # password = 'y26W99322-84294',
#     # folder   = 'BCEHS',
#     username = 'michael.kuo@bccdc.ca',
#     password = keyring::key_get('michael.kuo'),
#     port     = 22
#   ),
#   .recursive = T
# )

