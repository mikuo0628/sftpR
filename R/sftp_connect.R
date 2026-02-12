#' SFTP Connection Class
#'
#' @description
#' An R6 class to manage SFTP connections, handle authentication, and perform
#' robust file transfers using `curl`. Credentials and handles are stored
#' internally to prevent repeated authentication.
#'
#' @details
#' The class uses a "streaming" upload mechanism (via `readfunction`) to handle
#' large files efficiently without loading them entirely into memory.
#'
#' @export
sftp_connect <- R6::R6Class(
  "SFTPConn",
  public = list(
    #' @field protocol The connection protocol (defaults to "sftp://").
    protocol = "sftp://",
    #' @field hostname The server address or IP.
    hostname = "localhost",
    #' @field folder The target subdirectory on the server.
    folder = NULL,
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
    #' @param folder Character. Sub-path on server.
    #' @param port Integer. Port number.
    #' @param username Character. SFTP account name.
    #' @param password Character. SFTP password.
    #' @param timeout Integer. Connection timeout.
    #' @param .verbose Logical. Toggle verbose output.
    #' @param ... Additional arguments passed to [curl::handle_setopt()].
    #' @return A new `SFTPConn` object.
    initialize =
      function(protocol = "sftp://",
               hostname = "localhost",
               folder   = NULL,
               port     = 22L,
               username = NA_character_,
               password = NA_character_,
               timeout  = 30L,
               ...,
               .verbose = FALSE) {
        self$protocol    <- protocol
        self$hostname    <- hostname
        self$folder      <- folder
        self$port        <- port
        self$timeout     <- timeout
        self$.verbose    <- .verbose
        private$username <- username
        private$password <- password

        # check protocol "sftp" exists
        sftp_check <- "sftp" %in% curl::curl_version()$protocol
        if (isFALSE(sftp_check)) {
          stop("Please check if `curl` contains `sftp` protocol")
        }

        # create base handle
        h <- curl::new_handle()
        curl::handle_setopt(
          h,
          userpwd = paste0(private$username, ":", private$password),
          ssh_auth_types = 2,
          verbose = .verbose,
          ...
        )
        self$h <- h

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
      # host check
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
    #' Adapted from [curl::curl_upload()].
    #' @param local_file Path to file, data.frame, or connection.
    #' @param reuse Logical; try to keep connection alive.
    #' @param ... Additional options for [curl::handle_setopt()].
    .upload_handle = function(local_file, reuse = TRUE, ...) {
      # check if `local_file` exists
      if (is.character(local_file)) {
        if (!file.exists(local_file)) {
          stop("Provided `local_file` does not exist.")
        }
      } else {
        # if `local_file` is data, write it to a temp file
        tempfile_used <- TRUE
        temp_local_file <- tempfile()
        print_verbose_msg(
          self$.verbose,
          paste(
            sep = "\n",
            paste(
              "Provided `local_file` is a data object,",
              "not a path to a physical file."
            ),
            "It will be written to a temp file before uploading.",
            sprintf("The temp file is: %s", temp_local_file)
          )
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
      # create upload handle with streaming read and seek functions
      total_bytes <- 0
      h <-
        curl::new_handle(
          upload = TRUE,
          filetime = FALSE,

          # adopted callback mechanism
          # from curl::curl_upload()'s handle settings
          readfunction = function(n) {
            buffer <- readBin(file_conn, what = raw(), n = n)
            total_bytes <<- total_bytes + length(buffer)
            if (self$.verbose) {
              if (length(buffer) == 0 || identical(total_bytes, infilesize)) {
                cat(
                  sprintf(
                    "\rUpload %.0f bytes... all done!\n",
                    total_bytes
                  ),
                  file = stderr()
                )
              } else {
                cat(
                  sprintf(
                    "\rUpload %.0f bytes...", total_bytes
                  ),
                  file = stderr()
                )
              }
            }
            return(buffer)
          },

          # adopted "rewind" mechanism
          # from curl::curl_upload()'s handle settings
          seekfunction = function(offset) seek(file_conn, where = offset),
          forbid_reuse = !isTRUE(reuse),
          userpwd = paste0(private$username, ":", private$password),
          ssh_auth_types = 2,
          verbose = self$.verbose,
          ...
        )

      if (!is.na(infilesize)) {
        curl::handle_setopt(h, infilesize_large = infilesize)
      }

      return(list(h = h, file_conn = file_conn))
    }
  ),
  active = list(
    #' @field clean_url Returns the processed SFTP URL via `build_sftp_url`.
    clean_url = function() {
      build_sftp_url(
        protocol = self$protocol,
        hostname = self$hostname,
        port     = self$port,
        folder   = self$folder
      )
    }
  ),
  private = list(
    username = NA_character_,
    password = NA_character_
  )
)
