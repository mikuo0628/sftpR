#' Create an \code{SFTPConn} R6 object that contains important connection
#' information safely
#'
#' @inherit sftp_conn_generator description
#'
#' @inheritParams shared_params
#'
#' @inherit sftp_conn_generator details
#'
#' @inherit sftp_conn_generator return
#'
#' @examples
#' \donttest{
#' # Create a new SFTP connection
#' sftp_conn <- sftp_connect(
#'   hostname = "127.0.0.1",
#'   port     = 2222,
#'   user     = "tester",
#'   password = "password123"
#' )
#' }
#'
#' @export
sftp_connect <- function(
    protocol = "sftp",
    hostname = "localhost",
    path = NULL,
    port = "22",
    user = NA_character_,
    password = NA_character_,
    timeout = 30L,
    ...,
    .verbose = TRUE) {
  sftp_conn_generator$new(
    protocol = protocol,
    hostname = hostname,
    path     = path,
    port     = port,
    user     = user,
    password = password,
    timeout  = timeout,
    .verbose = .verbose,
    ...
  )
}

#' SFTP Connection Class
#'
#' @name sftp_conn_generator
#'
#' @description
#' An R6 class to safely store information needed for SFTP connection,
#' with convenient methods to check connections and existence of files or
#' directories, and create specific handles for \code{sftp_*} function family of
#' CRUD operations.
#'
#' @details
#' One important goal of this design choice is to keep user credentials
#' safe, as private fields. Credentails are used to create specific handles
#' for \code{sftp_*} family, and are reused where approrpiate. \code{SFTPConn}
#' This class checks if credential is valid, and has a internal convenience
#' methods such as safe printing for basic information, checking destination
#' existence, and ensuring URL is correctly formatted.
#'
#' @return \code{SFTPConn} R6 class object, used in \code{sftp_*} family.
#'
#' @keywords internal
#'
#' @importFrom R6 R6Class
sftp_conn_generator <- R6::R6Class(
  "SFTPConn",
  public = list(
    #' @field protocol The connection protocol.
    protocol = NULL,

    #' @field hostname The server address or IP.
    hostname = NULL,

    #' @field path The target subdirectory on the server.
    path = NULL,

    #' @field port The port number.
    port = NULL,

    #' @field timeout Connection timeout in seconds.
    timeout = NULL,

    #' @field h The internal curl handle used for connection checks, listing
    #'   directories, and download files.
    h = NULL,

    #' @field .verbose Logical; if TRUE, prints detailed curl output.
    .verbose = NULL,

    #' @field last_error Character string of the last connection error.
    last_error = NULL,

    #' @description
    #' Initialize `SFTPConn` class R6 object.
    #'
    #' @param protocol Character. Protocol string. Defaults to "sftp".
    #'
    #' @param hostname Character. Server URL or IP. Defaults to "localhost".
    #'
    #' @param path Character. Sub-path on server.
    #'
    #' @param port Character. Port number. Defaults to "22".
    #'
    #' @param user Character. SFTP account name.
    #'
    #' @param password Character. SFTP password.
    #'
    #' @param timeout Integer. Connection timeout.
    #'
    #' @param ... Additional arguments passed to \code{curl::handle_setopt()}.
    #'
    #' @param .verbose Logical. Defaults to \code{TRUE}.
    #'   Prints helpful messages.
    #'
    #' @return An `SFTPConn` object with safely stored user credential and
    #'  convenience methods for various operations, such as checking connection
    #'  and existence, and creating handles for CRUD operations.
    initialize = function(protocol = "sftp",
                          hostname = "localhost",
                          path     = NULL,
                          port     = "22",
                          user     = NA_character_,
                          password = NA_character_,
                          timeout  = 30L,
                          ...,
                          .verbose = TRUE) {
      .clean_url <-
        .build_sftp_url(
          protocol = protocol,
          user     = user,
          hostname = hostname,
          port     = port,
          path     = path,
          .verbose = .verbose
        )

      self$protocol    <- .clean_url$protocol
      self$hostname    <- .clean_url$hostname
      self$path        <- .clean_url$path
      self$port        <- .clean_url$port
      self$timeout     <- timeout
      self$.verbose    <- .verbose
      private$user     <- .clean_url$user
      private$password <- password

      # check protocol "sftp" exists
      sftp_check <- "sftp" %in% curl::curl_version()$protocol
      if (isFALSE(sftp_check)) {
        stop("Please check if `curl` contains `sftp` protocol")
      }

      # create base handle
      self$h <- private$.base_handle(...)

      # Check initial connection
      if (isFALSE(self$connection_ok())) {
        stop(
          paste0(
            sprintf(
              "\nCannot connect to SFTP server at %s.\n",
              self$clean_url$full_url
            ),
            self$last_error
          )
        )
      }
    },

    #' @description
    #' Checks if the current connection settings and credentials are valid.
    #' @return Logical; TRUE if connection is successful.
    connection_ok = function() {
      host_check <-
        try(
          silent = TRUE,
          curl::curl_fetch_memory(self$clean_url$full_url, handle = self$h)
        )
      if (inherits(host_check, "try-error")) {
        self$last_error <- conditionMessage(attr(host_check, "condition"))
        return(FALSE)
      }
      self$last_error <- NULL
      return(TRUE)
    },

    #' @description
    #' Custom print method to display connection status without exposing
    #' passwords.
    #'
    #' @param ... Unused.
    print = function(...) {
      cat("<SFTP Connection>\n")

      # Show public info
      cat(paste0("  Protocol: ", self$protocol, "\n"))
      cat(paste0("  Host:     ", self$hostname, "\n"))
      cat(paste0("  Port:     ", self$port, "\n"))

      # Show status of connection
      status <-
        if (isTRUE(self$connection_ok())) "[Connected]" else "[Not Connected]"
      cat(paste0("  Status:   ", status, "\n"))

      # Indicate credentials are held but hidden
      if (!is.null(private$password)) {
        cat("  Auth:     [Credentials Stored Safely]\n")
      } else {
        cat("  Auth:     [No Credentials Found]\n")
      }

      # Return self invisibly (R6 best practice)
      invisible(self)
    },

    #' @description
    #' Internal method to generate a specialized upload handle with streaming.
    #' Adapted from \code{curl::curl_upload()}.
    #'
    #' @inherit sftp_conn_generator description
    #'
    #' @param local_file Path to file, data.frame, or connection.
    #'
    #' @param reuse Logical; try to keep connection alive.
    #'
    #' @param ... Additional options for \code{curl::handle_setopt()}.
    #'
    #' @param .verbose Logical. Defaults to \code{TRUE}.
    #'   Prints helpful messages.
    .upload_handle =
      function(local_file, reuse = TRUE, .verbose = self$.verbose, ...) {
        # check if `local_file` exists
        tempfile_used <- FALSE
        if (is.character(local_file)) {
          if (!file.exists(local_file)) {
            stop("Provided `local_file` does not exist.")
          }
        } else {
          # if `local_file` is data, write it to a temp file
          tempfile_used <- TRUE
          temp_local_file <- tempfile()
          .verbose_msg(
            .verbose = .verbose,
            paste(
              sep = "\n",
              paste(
                "= Provided `local_file` is a data object,",
                "not a path to a physical file."
              ),
              "== It will be written to a temp file before uploading.",
              sprintf("== The temp file is: %s", temp_local_file)
            ),
            warning
          )
          try_write_temp_file <-
            try(
              silent = TRUE,
              utils::write.csv(x = local_file, file = temp_local_file)
            )
          if (inherits(try_write_temp_file, "try-error")) {
            stop(
              "The data in `local_file` cannot be written to a temporary file."
            )
          }
          # update `local_file` to point to the temp file location
          local_file <- temp_local_file
        }
        file_conn <-
          if (is.character(local_file)) {
            local_file <- normalizePath(local_file, mustWork = TRUE)
            infilesize <- file.info(local_file)$size
            base::file(local_file, open = "rb")
          } else if (inherits(local_file, "connection")) {
            local_file
          } else {
            stop(
              paste(
                "`local_file` must be a data.frame,",
                "character path or a connection object."
              )
            )
          }

        # private states for tracking upload progress
        bytes_sent <- 0
        last_reported_ten <- -1
        # create upload handle with streaming read and seek functions
        h <-
          private$.base_handle(
            upload = TRUE,
            filetime = FALSE,

            # adopted callback mechanism
            # from curl::curl_upload()'s handle settings
            readfunction = function(n) {
              buffer <- readBin(file_conn, what = raw(), n = n)
              len_buffer <- length(buffer)

              bytes_sent <<- bytes_sent + length(buffer)

              # progress bar: 10% increments
              if (!is.na(infilesize) && infilesize > 0) {
                ## calculate progress percentage
                perc_complete <- bytes_sent / infilesize
                curr_ten <- floor(floor(perc_complete * 100) / 10) * 10

                if (.verbose && curr_ten > last_reported_ten) {
                  last_reported_ten <<- curr_ten
                  bar_width <- curr_ten / 10
                  bar <-
                    paste0(
                      "[",
                      strrep("=", bar_width),
                      strrep(" ", 10 - bar_width),
                      "]"
                    )
                  cat(
                    sprintf(
                      "\n\rUploading: %s %d%% (Total filesize: %.2f MB)\n\n",
                      bar, curr_ten, infilesize / (1024^2)
                    )
                  )
                  utils::flush.console()
                }
              }

              # Final "All Done" cleanup
              if (len_buffer == 0 && .verbose) {
                cat("\nUpload Complete.\n", file = stderr())
              }

              return(buffer)
            },

            # adopted "rewind" mechanism
            # from curl::curl_upload()'s handle settings
            seekfunction = function(offset) seek(file_conn, where = offset),
            forbid_reuse = !isTRUE(reuse),
            ...
          )

        if (!is.na(infilesize)) {
          curl::handle_setopt(h, infilesize_large = infilesize)
        }

        return(
          list(
            h = h,
            file_conn = file_conn,
            tempfile = if (isTRUE(tempfile_used)) local_file else NULL
          )
        )
      },

    #' @description
    #' Createshandle that uses `quote` option. Specifically for deleting,
    #' creating directories, and renaming files or directories.
    #'
    #' @param remote_url_from Character. The URL to delete, to create, or to
    #'   rename from.
    #'
    #' @param remote_url_to Character. The URL to rename to. Ignored for delete
    #'   or directory create operations.
    #'
    #' @param purpose Character. Choose one of 3 options:
    #'   \itemize{
    #'      \item "rm": to delete file or directory.
    #'      \item "mkdir": to create directory. Path should be a directory.
    #'      \item "rename": to rename
    #'   }
    #'
    #' @param .verbose Logical. Defaults to \code{TRUE}.
    #'   Prints helpful messages.
    #'
    #' @param .ignore_error Logical. Defaults to `FALSE`.
    #'   If \code{TRUE}, error will not interrupt subsequent execution.
    #'   See `Details`.
    #'
    #' @param ... Options that for \code{curl::handle_setopt()}.
    #'
    #' @details
    #'   In `curl`, adding an asterisk (`*`) at the very  beginning of a
    #'   command (ie. one of the 3 used in `purpose` argument)
    #'   acts as a "fail-safe" or "ignore-error" prefix. It silently ignores
    #'   any failure returned by the command, and continues without being
    #'   interrupted by the error.
    .quote_handle =
      function(remote_url_from = NULL,
               remote_url_to = NULL,
               purpose = c("rm", "mkdir", "rename"),
               .verbose = self$.verbose,
               .ignore_error = FALSE,
               ...) {
        # determine dir or file
        remote_url <-
          lapply(
            list(
              from = remote_url_from,
              to   = remote_url_to
            ),
            \(x) if (is.null(x)) return(NULL) else self$.fix_url_type(x)
          )

        relative_url <-
          lapply(
            remote_url,
            \(x) {
              if (is.null(x)) {
                return(NULL)
              }
              gsub(self$clean_url$full_url, "", x)
            }
          )

        # different commands depending on protocol and file/dir
        # detectable by trailing slash generated by .fix_url_type
        command <-
          switch(paste(
            purpose,
            tolower(self$protocol),
            grepl("/$", remote_url$from),
            sep = "_"
          ),
          "rm_sftp_TRUE" = "rmdir",
          "rm_sftp_FALSE" = "rm",
          "rm_ftp_TRUE" = "RMD",
          "rm_ftp_FALSE" = "DELE",
          "mkdir_sftp_TRUE" = "mkdir",
          "mkdir_sftp_FALSE" = "mkdir",
          "mkdir_ftp_TRUE" = "MKD",
          "mkdir_ftp_FALSE" = "MKD",
          "rename_sftp_TRUE" = "rename",
          "rename_sftp_FALSE" = "rename",
          "rename_ftp_TRUE" = "RNFR",
          "rename_ftp_FALSE" = "RNFR",
          stop(
            sprintf(
              "Unsupported protocol or type for %s.",
              switch(purpose,
                "rm"     = "deletion",
                "mkdir"  = "creating directory",
                "rename" = "renaming"
              )
            )
          )
          )

        if (isTRUE(.ignore_error)) command <- paste0("*", command)

        # remote risky trailing slash
        relative_url <-
          lapply(
            relative_url,
            \(x) if (is.null(x)) {
              return(NULL)
            } else {
              gsub("/$", "", x)
            }
          )

        # Function     Handle Intent     Quote Trailing (/)	Logic / Command
        # sftp_list    Listing           NO    YES          none
        # sftp_upload  Data Transfer     NO*   NO           upload = TRUE
        # sftp_delete  Command Execution YES   NO           rm or rmdir
        # sftp_mkdir   Command Execution YES   NO           mkdir
        # sftp_rename  Command Execution YES   NO           rename old new
        # sftp_exists  Metadata (STAT)   NO    OPTIONAL     nobody = TRUE
        # Type Checker Range Probe       NO    NO           range = "0-0"

        quote <- paste(command, relative_url$from)
        h <-
          if (purpose == "rename") {
            quote <-
              if (self$protocol == "sftp") {
                paste(
                  "rename",
                  paste(
                    collapse = " ",
                    do.call(
                      sprintf,
                      append(list("\"%s\" \"%s\""), relative_url)
                    )
                  )
                )
              } else if (protocol == "ftp") {
                paste(paste("RNFR", "RNTO"), relative_url)
              }

            private$.base_handle(
              quote = quote,
              ...
            )
          } else if (purpose == "mkdir") {
            private$.base_handle(
              quote = quote,
              ...
            )
          } else if (purpose == "rm") {
            private$.base_handle(
              quote = quote,
              ...
            )
          }

        .verbose_msg(
          .verbose = .verbose, sprintf("`quote` = \"%s\"", quote), message
        )
        return(h)
      },

    #' Check if a remote path exists
    #'
    #' @description
    #' An internal helper that pings the SFTP/FTP server to verify
    #' the existence of a file or directory.
    #'
    #' @details
    #' This method uses \code{CURLOPT_NOBODY = TRUE} to perform a
    #' protocol-level \code{STAT} request. This is highly efficient
    #' as it retrieves only metadata and does not attempt to download or
    #' list contents.
    #'
    #' Because \code{STAT} is slash-agnostic in the SFTP protocol, this check
    #' will return \code{TRUE} for a directory regardless of whether a trailing
    #' forward-slash is provided in the URL.
    #'
    #' However, this is the only operation where URL is "safe" from the
    #' consequences of un-normalized URLs. Be wary of incorrect multiple
    #' slash placements as they will be collapsed into one slash and won't
    #' throw errors.
    #'
    #' @param sftp_url Character. The full URL to the remote resource.
    #'   If \code{NULL}, returns \code{FALSE}.
    #'
    #' @return Logical. \code{TRUE} if the resource exists and is accessible;
    #'   \code{FALSE} otherwise.
    .exists =
      function(sftp_url = NULL) {
        if (is.null(sftp_url)) stop("`sftp_url` cannot be NULL")
        # STAT request with `nobody` = T
        h <- private$.base_handle(nobody = TRUE, connecttimeout = 5)
        check <-
          try(
            curl::curl_fetch_memory(url = sftp_url, handle = h),
            silent = TRUE
          )
        return(!inherits(check, "try-error") && !is.na(check$modified))
      },

    #' URL "fixing" via range probing
    #'
    #' @description
    #' An internal diagnostic method that determines if a remote URL requires a
    #' trailing slash by attempting to read a single byte (Range: 0-0).
    #'
    #' @details
    #' This method leverages a protocol behavior:
    #' \itemize{
    #'   \item \strong{Files} allow byte-range requests; the probe succeeds.
    #'   \item \strong{Directories} reject byte-range requests; the probe fails.
    #' }
    #'
    #' If the initial probe fails, the method "flips" the trailing slash
    #'   (adds one if missing, or removes one if present) and returns the
    #'   modified URL. This addresses the common `libcurl` issue where directory
    #'   listings fail without an explicit trailing slash.
    #'
    #' @param remote_url Character. The full SFTP/FTP URL to validate.
    #'
    #' @return A character string containing the "fixed" URL. Note that if the
    #'   path truly does not exist, the flipped URL is still returned; the final
    #'   operation (upload/list) will handle the ultimate failure.
    #'
    #' @note This method uses a 5-second \code{connecttimeout} to ensure
    #'   the probe doesn't hang on unresponsive servers.
    .fix_url_type =
      function(remote_url) {
        # requesting the first byte of data (CURLOPT_RANGE 0-0)
        ## only works if URL is a file, and will reject request if URL is dir
        if (!isTRUE(self$.exists(remote_url))) {
          .verbose_msg(
            .verbose = self$.verbose,
            "URL does not exist. No change will be made.",
            warning
          )
          return(remote_url)
        }

        h <- private$.base_handle(range = "0-0", connecttimeout = 5)

        accessible <-
          !inherits(
            try(
              curl::curl_fetch_memory(url = remote_url, h = h),
              silent = TRUE
            ),
            "try-error"
          )

        if (isTRUE(accessible)) {
          return(remote_url)
        }

        remote_url <-
          ifelse(
            grepl("/$", remote_url),
            gsub("/$", "", remote_url),
            paste0(remote_url, "/")
          )

        return(remote_url)
      }
  ),
  active = list(
    #' @field clean_url Returns the processed SFTP URL via internal
    #' \code{.build_sftp_url}.
    clean_url = function() {
      .build_sftp_url(
        protocol = self$protocol,
        user     = private$user,
        hostname = self$hostname,
        port     = self$port,
        path     = self$path,
        .verbose = self$.verbose
      )
    }
  ),
  private = list(
    user = NA_character_,
    password = NA_character_,
    .base_handle =
      function(..., .verbose = self$.verbose) {
        h <- curl::new_handle()
        curl::handle_setopt(
          h,
          userpwd = paste0(private$user, ":", private$password),
          ssh_auth_types = 2,
          verbose = .verbose,
          timeout = self$timeout,
          ...
        )
        return(h)
      }
  )
)
