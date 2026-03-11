#' SFTP Connection Class
#'
#' @description
#' An R6 class to manage SFTP connections, handle authentication, and perform
#' robust file transfers using \code{curl}. Credentials and handles are stored
#' internally to prevent repeated authentication.
#'
#' @details
#' The class uses a "streaming" upload mechanism (via \code{readfunction}) to
#' handle large files efficiently without loading them entirely into memory.
#'
#' @return
#' An `SFTPConn` object with methods for connection management and
#' file uploads.
#'
#' @examples
#' \dontrun{
#' # Create a new SFTP connection
#' sftp_conn <- sftp_connect$new(
#'   hostname = "127.0.0.1",
#'   port     = 2222,
#'   user     = "tester",
#'   password = "password123",
#' }
#'
#' @export
sftp_connect <- R6::R6Class(
  "SFTPConn",
  public = list(
    #' @field protocol The connection protocol (defaults to "sftp://").
    protocol = "sftp://",
    #' @field hostname The server address or IP.
    hostname = "localhost",
    #' @field path The target subdirectory on the server.
    path = NULL,
    #' @field port The port number (defaults to 22).
    port = 22L,
    #' @field timeout Connection timeout in seconds.
    timeout = 30L,
    #' @field h The internal curl handle used for connection checks.
    h = NULL,
    #' @field .verbose Logical; if TRUE, prints detailed curl output.
    .verbose = TRUE,

    #' @description
    #' Create a new SFTP connection object.
    #' @param protocol Character. Protocol string.
    #' @param hostname Character. Server URL or IP.
    #' @param path Character. Sub-path on server.
    #' @param port Integer. Port number.
    #' @param user Character. SFTP account name.
    #' @param password Character. SFTP password.
    #' @param timeout Integer. Connection timeout.
    #' @param .verbose Logical. Toggle verbose output.
    #' @param ... Additional arguments passed to \code{curl::handle_setopt()}.
    #' @return A new `SFTPConn` object.
    initialize =
      function(protocol = "sftp",
               hostname = "localhost",
               path     = NULL,
               port     = 22L,
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
              "Unable to connect to SFTP server at ",
              self$clean_url$full_url,
              ". Please check your connection settings and credentials."
            )
          )
        }
      },

    #' @description
    #' Checks if the current connection settings and credentials are valid.
    #' @return Logical; TRUE if connection is successful.
    connection_ok = function() {
      status <- TRUE
      host_check <-
        try(
          silent = TRUE,
          curl::curl_fetch_memory(self$clean_url$full_url, handle = self$h)
        )
      if (inherits(host_check, "try-error")) status <- FALSE
      return(status)
    },

    #' @description
    #' Custom print method to display connection status without exposing
    #' passwords.
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
    #' @param local_file Path to file, data.frame, or connection.
    #' @param reuse Logical; try to keep connection alive.
    #' @param ... Additional options for \code{curl::handle_setopt()}.
    #' @keyword internal
    #' @noRd
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
                      bar, curr_ten, infilesize / (1024 ^ 2)
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
    #' An internal factory method that generates an authenticated curl handle
    #' configured with the appropriate protocol-specific deletion command
    #' (e.g., \code{rm}, \code{rmdir}, \code{DELE}, or \code{RMD}).
    #' @param remote_url
    #'   Character. Validated (ie. with \code{.validate_sftp_url()})
    #'   remote path to the file or directory to be deleted.
    #'   Whether this is a directory or file will be determined and the
    #'   approrpiate DELETE keyword will be determined.
    #' @param protocol Character. The protocol to use (defaulting to the
    #'   connection's \code{self$protocol}). Supported: "sftp", "ftp".
    #' @param .verbose Logical. Toggle verbose output.
    #' @param ... Additional arguments passed to \code{private$.base_handle()}
    #'   and \code{curl::handle_setopt()}.
    #' @keyword internal
    #' @noRd
    .delete_handle =
      function(
        remote_url,
        protocol = self$protocol,
        .verbose = self$.verbose,
        ...
      ) {
        # determine dir or file, and remove "base" URL
        remote_url <- private$.fix_url_type(remote_url)
        remote_url <- gsub(self$clean_url$full_url, "", remote_url)

        # check is_dir
        is_dir <- grepl("/$", remote_url)

        remove_method <-
          switch(
            paste0(tolower(protocol), "_", is_dir),
            "sftp_TRUE"  = "rmdir",
            "sftp_FALSE" = "rm",
            "ftp_TRUE"   = "RMD",
            "ftp_FALSE"  = "DELE",
            stop("Unsupported protocol or type")
          )

        h <-
          private$.base_handle(
            quote = paste(remove_method, remote_url),
            ...
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
    #'
    #' @keyword internal
    #' @noRd
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
        return(!inherits(check, "try-error"))
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
    user         = NA_character_,
    password     = NA_character_,
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
    #'
    #' @keyword internal
    #' @noRd
    .fix_url_type =
      function(remote_url) {
        # requesting the first byte of data (CURLOPT_RANGE 0-0)
        ## only works if URL is a file, and will reject request if URL is dir
        h <- private$.base_handle(range = "0-0", connecttimeout = 5)

        accessible <-
          !inherits(
            try(
              curl::curl_fetch_memory(url = remote_url, h = h),
              silent = TRUE
            ),
            "try-error"
          )

        if (isTRUE(accessible)) return(remote_url)

        remote_url <-
          ifelse(
            grepl("/$", remote_url),
            gsub("/$", "", remote_url),
            paste0(remote_url, "/")
          )

        return(remote_url)
      }
  )
)
