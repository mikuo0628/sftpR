sftp_mkdir <- function(dir_name, protocol, server, base_folder = "upload") {
  # Build the URL and the command
  target_url <- .build_sftp_url(protocol, server, base_folder)
  mkdir_cmd <- paste0("mkdir ", base_folder, "/", gsub("^/", "", dir_name))
  
  h <- get_sftp_handle()
  curl::handle_setopt(h, quote = mkdir_cmd)
  
  # A fetch is required to trigger the 'quote' command
  tryCatch({
    curl::curl_fetch_memory(target_url, handle = h)
    message("Successfully created: ", dir_name)
  }, error = function(e) {
    stop("Failed to create directory. Ensure it doesn't already exist or check permissions.")
  })
}