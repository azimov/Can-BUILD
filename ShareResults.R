################################################################################
# Share your results with the study coordinator
#
# WHAT THIS DOES
#   1. Zips the aggregate result files in results/<databaseName>/.
#   2. Optionally uploads that ZIP over SFTP.
#
# WHAT IS IN THE ZIP
#   Only the CSV files produced by Strategus. These are aggregate counts and
#   statistics. They do not contain patient-level data.
#
# THE UPLOAD IS YOUR CHOICE
#   Step 1 always runs and leaves a ZIP file on your disk. Step 2 (the upload)
#   only runs if you say yes. If you say no, the ZIP stays where it is and you
#   send it however your coordinator asked - email, a shared drive, whatever
#   you prefer.
#
#   Read the path below before agreeing: it is the only thing in this study
#   that sends anything off your machine, and it sends exactly one ZIP file to
#   the server you name.
################################################################################

##=========== START OF INPUTS ==========

# Name used in ExecuteAnalyses.R (it is the results sub-folder).
databaseName <- "MY_SITE"

# Where the results were written. Relative paths are from this folder.
resultsFolder <- "results"

# SFTP details, from your study coordinator. Leave them as they are if you are
# not uploading.
sftpKeyFileName <- ""
sftpUserName <- ""
sftpRemoteFolderName <- ""

##=========== END OF INPUTS ==========


################################################################################
# Below this line nothing changes unless you answer a question.
################################################################################

zip_results <- function(resultsFolder, zipFile) {
  # Strategus::zipResults needs absolute paths.
  resultsFolder <- normalizePath(resultsFolder, mustWork = TRUE)
  zipFile <- normalizePath(dirname(zipFile), mustWork = TRUE) |>
    file.path(basename(zipFile))
  cat("\nZipping results\n")
  cat("  From: ", resultsFolder, "\n", sep = "")
  cat("  To:   ", zipFile, "\n", sep = "")
  Strategus::zipResults(resultsFolder = resultsFolder, zipFile = zipFile)
  cat("  Done: ", format(file.info(zipFile)$size), " bytes\n", sep = "")
}

upload_results <- function(zipFile, keyFile, userName, remoteFolder) {
  cat("\nUploading over SFTP\n")
  cat("  File:          ", zipFile, "\n", sep = "")
  cat("  Server folder: ", remoteFolder, "\n", sep = "")
  cat("  User:          ", userName, "\n", sep = "")
  cat("  Private key:   ", keyFile, "\n", sep = "")
  OhdsiSharing::sftpUploadFile(
    privateKeyFileName = keyFile,
    userName = userName,
    remoteFolder = remoteFolder,
    fileName = zipFile
  )
  cat("  Upload finished.\n")
}

run_share <- function() {
  # Work out the folder and zip name from the settings above.
  # results/SYNTHEA10K when the parent exists; accept the folder itself too.
  candidate <- file.path(resultsFolder, databaseName)
  folder <- if (dir.exists(candidate)) {
    candidate
  } else if (dir.exists(resultsFolder) &&
             length(list.files(resultsFolder, pattern = "[.]csv$", recursive = TRUE)) > 0) {
    resultsFolder
  } else {
    stop(
      "Could not find results for '", databaseName, "' in: ", resultsFolder,
      "\nCheck that databaseName matches the name used in ExecuteAnalyses.R.",
      call. = FALSE
    )
  }
  zipFile <- file.path(folder, paste0(databaseName, ".zip"))

  # Show what is about to be shared.
  files <- list.files(folder, pattern = "\\.csv$", recursive = TRUE)
  cat("\n", strrep("=", 70), "\n", sep = "")
  cat("  Sharing results for: ", databaseName, "\n", sep = "")
  cat(strrep("=", 70), "\n", sep = "")
  cat("  Folder:      ", folder, "\n", sep = "")
  cat("  CSV files:   ", length(files), "\n", sep = "")
  cat("  These files are aggregate results only (counts and statistics).\n")
  cat("  They do not contain patient-level data.\n")

  zip_results(folder, zipFile)

  # The upload is a separate, explicit decision.
  canUpload <- all(
    nzchar(sftpKeyFileName),
    nzchar(sftpUserName),
    nzchar(sftpRemoteFolderName)
  )
  if (!canUpload) {
    cat("\nNo SFTP details were filled in at the top of this script, so nothing\n")
    cat("has been uploaded. The ZIP is ready to send however you prefer:\n")
    cat("  ", zipFile, "\n", sep = "")
    return(invisible(zipFile))
  }

  cat("\n")
  cat(strrep("-", 70), "\n", sep = "")
  cat("  The next step UPLOADS this ZIP off your machine.\n")
  cat("  It goes to:  ", sftpRemoteFolderName, "  as  ", sftpUserName, "\n", sep = "")
  answer <- readline("  Type UPLOAD to send it, or press Enter to skip: ")
  if (!identical(tolower(trimws(answer)), "upload")) {
    cat("\n  Not uploading. The ZIP is still on your disk:\n")
    cat("  ", zipFile, "\n", sep = "")
    return(invisible(zipFile))
  }

  upload_results(zipFile, sftpKeyFileName, sftpUserName, sftpRemoteFolderName)
  invisible(zipFile)
}

if (!interactive()) {
  cat("\nShareResults.R asks before uploading, so it needs an interactive R\n")
  cat("session. Nothing has been zipped or uploaded.\n")
  cat("\nOpen R or RStudio in this folder and run:\n")
  cat("    source(\"ShareResults.R\")\n\n")
} else {
  run_share()
}
