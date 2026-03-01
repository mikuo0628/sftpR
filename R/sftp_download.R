sftp_download <- function(
    sftp_conn = NULL,
    path_file = NA_character_,
    path_save = NA_character_,
    .verbose  = T,
    ...
) {

  .verbose_msg <- function(msg, .print = .verbose) { if (.print) message(msg) }

  browser()
  # cases:
  # 0 path_file, 1 path_save: generate path_save
  # 0 path_file, 0 path_save: generate path_save
  # 0 path_file, n path_save: error
  # 1 path_file, 1 path_save: generate path_save
  # 1 path_file, 0 path_save: generate path_save
  # 1 path_file, n path_save: error
  # n path_file, 0 path_save: generate path_save
  # n path_file, 1 path_save: generate path_save
  # n path_file, n path_save: 1-to-1
  # n path_file, m path_save: error

  # set up errors
  err_msgs <-
    c(
      "More `path_save` that can be logically assigned downloadable files.",
      "No downloadable files found."
    )

  if (is.na(path_file) & length(path_save) > 0)       { stop(err_msgs[1]) }
  if (length(path_file) == 1 & length(path_save) > 0) { stop(err_msgs[1]) }
  if (length(path_file) != length(path_save))         { stop(err_msgs[1]) }

  if (is.na(path_file) || path_file == '*') {

    # list and download all files if NA or wildcard
    df_files <- subset(sftp_list(sftp_conn, .recursive = T), type == 'file')

  }

  if (is.na(path_save)) path_save <- getwd()

  file.info(
    c(
      path_save,
      file.path(path_save, 'test.txt')
    )
  )$isdir

  df_files$path_save <- path_save

  # TODO: check if path_save is file, path_save and path_file are equal length
  # TODO: iterate downloads

  file.info(path_save)$isdir
  file.exists(path_save)
  dir.exists(path_save)
  dir.exists(file.path(path_save, 'test.txt'))

  curl::curl_download(
    url = file.path(gsub('/$', '', df_files$url), df_files$name)[1],
    destfile = file.path(path_save, df_files$name[1]),
    quiet = F,
    handle = sftp_conn$h
  )


}
