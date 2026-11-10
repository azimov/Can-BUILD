################################################################################
# Fast install of the study packages from prebuilt binaries
#
# WHY THIS EXISTS
# ---------------
# CRAN publishes macOS ARM binaries per macOS release:
#
#   bin/macosx/sonoma-arm64/contrib/4.6   <- macOS 14+, Apple silicon
#
# R cannot be pointed at that tree with options(repos = ...): contrib.url()
# always appends "bin/macosx/contrib/<R x.y>" to whatever base you give it, so
# every repository URL you can express resolves to a path that does not exist
# and R falls back to compiling from source. That is why `renv::restore()` took
# ~30 minutes and why packages like mgcv failed to build on machines without a
# Fortran compiler.
#
# This script reads CRAN's PACKAGES index for the binary tree directly and
# installs the exact versions pinned in renv.lock from prebuilt .tgz files.
#
# WHAT IT DOES NOT DO
# -------------------
# It does not change renv.lock, does not connect to your database, and does not
# touch patient data. It downloads packages from cloud.r-project.org and
# installs them into renv/library.
#
# USAGE
# -----
#   source("renv/InstallPackages.R")
#
# Then run the study as usual.
#
# Packages CRAN has no binary for (strategus, cohortdiagnostics and other
# GitHub-hosted HADES packages) are installed from source afterwards by
# renv::restore(), which will only build those.
################################################################################

installFromBinaries <- function(
    lockfile = "renv.lock",
    library = .libPaths()[1],
    osMajor = as.integer(sub("^darwin", "", R.version$os)),
    verbose = TRUE) {

  isArm <- grepl("aarch64|arm64", R.version$arch)
  if (!isArm) {
    message("Not Apple silicon - use renv::restore() instead.")
    return(invisible(FALSE))
  }

  # R.version$minor is "6.2" in R 4.6.2, so take only the major.minor part.
  rver <- paste0(R.version$major, ".",
                 strsplit(R.version$minor, ".", fixed = TRUE)[[1]][1])
  channel <- if (osMajor >= 23) "sonoma-arm64" else "big-sur-arm64"
  base <- sprintf("https://cloud.r-project.org/bin/macosx/%s/contrib/%s",
                  channel, rver)

  if (verbose) {
    message("Binary source: ", base)
  }

  # Check the tree exists for this R version before touching anything.
  index <- tryCatch(
    readLines(file.path(base, "PACKAGES"), warn = FALSE),
    error = function(e) NULL
  )
  if (is.null(index) || length(index) < 10) {
    message("No binary packages published for macOS ", channel,
            " and R ", rver, ".")
    message("Falling back: run renv::restore() (this will compile from source).")
    return(invisible(FALSE))
  }

  binVersion <- function(pkg) {
    i <- grep(paste0("^Package: ", pkg, "$"), index)
    if (!length(i)) NA_character_ else sub("^Version: ", "", index[i + 1L])
  }

  lock <- jsonlite::fromJSON(lockfile, simplifyVector = FALSE)$Packages
  wanted <- vapply(lock, function(x) x$Version, character(1))
  available <- vapply(names(wanted), binVersion, character(1))
  use <- names(wanted)[!is.na(available) & available == wanted]

  if (verbose) {
    message(sprintf("%d of %d packages have a prebuilt binary; installing those.",
                    length(use), length(wanted)))
  }

  dir.create(library, recursive = TRUE, showWarnings = FALSE)
  tmp <- file.path(tempdir(), "canbuild-binary")
  dir.create(tmp, recursive = TRUE, showWarnings = FALSE)

  ok <- vapply(use, function(pkg) {
    ver <- wanted[[pkg]]
    dest <- file.path(tmp, sprintf("%s_%s.tgz", pkg, ver))
    url <- sprintf("%s/%s_%s.tgz", base, pkg, ver)
    got <- tryCatch({
      utils::download.file(url, dest, quiet = TRUE, mode = "wb")
      TRUE
    }, error = function(e) FALSE, warning = function(w) FALSE)
    if (!got || !file.exists(dest) || file.size(dest) < 1000) return(FALSE)
    status <- attr(
      system2(file.path(R.home("bin"), "R"),
              c("CMD", "INSTALL", "--library", library, dest),
              stdout = FALSE, stderr = FALSE),
      "status"
    )
    is.null(status) || identical(status, 0L)
  }, logical(1))

  if (verbose) {
    message(sprintf("Installed %d of %d packages from binaries.",
                    sum(ok), length(use)))
    remaining <- setdiff(names(wanted), use)
    if (length(remaining)) {
      message(sprintf(
        "%d package(s) have no binary and still need building: %s",
        length(remaining), paste(head(remaining, 8), collapse = ", ")
      ))
      message("Run renv::restore() to build those from source.")
    }
  }

  invisible(sum(ok))
}

if (interactive()) {
  installFromBinaries()
}
