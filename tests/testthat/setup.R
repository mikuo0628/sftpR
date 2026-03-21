# Check for connectivity once at the start
test_sftp <- has_test_sftp()
if (is.character(test_sftp)) {
  message(
    sprintf("SFTP test container not found: %s\n", test_sftp),
    "\nSkipping SFTP integration tests."
  )
}

# global clean "upload
sapply(
  list.files('upload', full.names = TRUE),
  unlink, recursive = TRUE, force = TRUE
)