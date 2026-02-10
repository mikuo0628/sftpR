print_verbose_msg <- function(verbose = FALSE, msg = "") {
  if (isTRUE(verbose)) {
    message(msg)
  }
}
