# Check for connectivity once at the start
if (!has_test_sftp()) {
  message(
    "SFTP test container not found at 127.0.0.1:2222.",
    "\nSkipping SFTP integration tests."
  )
}

# global clean "upload
sapply(
  list.files('upload', full.names = TRUE),
  unlink, recursive = TRUE, force = TRUE
)