if (
  !identical(Sys.getenv("GITHUB_ACTIONS"), "true") &&
    !identical(Sys.getenv("ACT"), "true")
) {
  source("renv/activate.R")
  options(
    repos =
      c(ppm = "https://packagemanager.posit.co/cran/__linux__/jammy/latest")
  )
}
