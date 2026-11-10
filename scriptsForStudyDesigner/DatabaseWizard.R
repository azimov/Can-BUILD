################################################################################
# Setup wizard - step by step, for people who would rather be asked than read
#
# Normally you reach this by running DatabaseSetup.R and answering "y" when it
# offers the wizard. You can also call it directly:
#
#   source("DatabaseSetup.R", echo = FALSE)   # loads the check functions
#   runDatabaseWizard()
#
# WHAT IT WRITES
#   config.user.yml   your settings (not committed to git)
#   .Renviron         the password only (not committed to git)
#
# It writes nothing until you confirm at the end, so you can back out.
################################################################################

# Ask a question, showing the current or default value in brackets.
wizAsk <- function(question, default = "") {
  if (nzchar(default)) {
    answer <- readline(sprintf("%s [%s]: ", question, default))
    if (!nzchar(answer)) default else trimws(answer)
  } else {
    trimws(readline(sprintf("%s: ", question)))
  }
}

wizYesNo <- function(question, default = TRUE) {
  hint <- if (default) "Y/n" else "y/N"
  repeat {
    answer <- tolower(trimws(readline(sprintf("%s [%s]: ", question, hint))))
    if (!nzchar(answer)) return(default)
    if (answer %in% c("y", "yes")) return(TRUE)
    if (answer %in% c("n", "no")) return(FALSE)
    cat("  Please answer y or n.\n")
  }
}

wizHeading <- function(title) {
  cat("\n", strrep("-", 70), "\n", sep = "")
  cat(title, "\n")
  cat(strrep("-", 70), "\n", sep = "")
}

# Quote a value for YAML.
wizQuote <- function(x) {
  if (is.null(x) || !nzchar(x)) return("\"\"")
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub("\"", "\\\"", x, fixed = TRUE)
  sprintf("\"%s\"", x)
}

# Open a file for the user to edit, using usethis when available.
wizOpenFile <- function(path) {
  if (requireNamespace("usethis", quietly = TRUE)) {
    usethis::edit_file(path)
  } else {
    cat("  Open this file in your editor:\n      ", path, "\n", sep = "")
  }
}

# ------------------------------------------------------------------------------
# The wizard
# ------------------------------------------------------------------------------
runDatabaseWizard <- function(projectRoot = getwd()) {
  cat("\n", strrep("=", 70), "\n", sep = "")
  cat("  Can-BUILD - setup wizard\n")
  cat(strrep("=", 70), "\n\n", sep = "")
  cat("This asks a few questions and writes two files:\n")
  cat("  config.user.yml   your settings      (not committed)\n")
  cat("  .Renviron         your password only (not committed)\n")
  cat("\nNothing is written until you confirm at the end.\n")

  # Existing values become the defaults, so re-running is safe.
  existing <- studyDatabaseSettings()

  # ---------------------------------------------------------------------------
  wizHeading("1. Database")
  cat("For PostgreSQL 'server' is usually host/database, e.g. db.example.org/cdm\n\n")

  dbms <- tolower(wizAsk("Database type", existing$dbms))
  server <- wizAsk("Server", existing$server)
  user <- wizAsk("User name", existing$user)

  # ---------------------------------------------------------------------------
  wizHeading("2. Schemas")
  cat("The CDM schema holds your OMOP tables AND the vocabulary.\n\n")

  cdmSchema <- wizAsk("CDM schema", existing$cdmDatabaseSchema)
  workSchema <- wizAsk("Work schema (must be writable)", existing$workDatabaseSchema)
  cohortTable <- wizAsk("Cohort table name", existing$cohortTableName)
  databaseName <- wizAsk(
    "Short name for this database (used for the results folder and password variable)",
    existing$databaseName
  )

  # ---------------------------------------------------------------------------
  wizHeading("3. JDBC driver")
  driverFolder <- wizAsk("Folder containing the JDBC driver (.jar files)",
                         existing$pathToDriver)
  if (!nzchar(driverFolder)) {
    if (wizYesNo("Download a driver now?", TRUE)) {
      dir.create(file.path(projectRoot, "jdbc"), showWarnings = FALSE)
      driverFolder <- DatabaseConnector::downloadJdbcDrivers(
        dbms, pathToDriver = file.path(projectRoot, "jdbc")
      )
      cat("  Saved to: ", driverFolder, "\n", sep = "")
    }
  }

  # ---------------------------------------------------------------------------
  wizHeading("4. Password")
  var <- passwordVariableName(databaseName)
  cat("The password goes in .Renviron, never in the YAML.\n")
  cat("It is stored as: ", var, "\n\n", sep = "")

  password <- ""
  if (requireNamespace("getPass", quietly = TRUE)) {
    password <- getPass::getPass("Password (blank to keep the current one): ")
  } else {
    password <- readline("Password (visible as you type): ")
  }

  # ---------------------------------------------------------------------------
  wizHeading("5. Test")
  cat("  Trying the connection...\n")

  Sys.setenv(DATABASECONNECTOR_JAR_FOLDER = driverFolder)
  details <- DatabaseConnector::createConnectionDetails(
    dbms = dbms, server = server, user = user, password = password,
    pathToDriver = driverFolder
  )
  conn <- tryCatch(DatabaseConnector::connect(details), error = function(e) e)

  tested <- !inherits(conn, "error")
  if (tested) {
    people <- tryCatch(
      DatabaseConnector::querySql(
        conn, sprintf("SELECT COUNT(*) AS N FROM %s.person;", cdmSchema))[[1]],
      error = function(e) e
    )
    DatabaseConnector::disconnect(conn)
    if (inherits(people, "error")) {
      cat("  Connected, but could not read ", cdmSchema, ".person\n", sep = "")
      cat("  ", conditionMessage(people), "\n", sep = "")
      if (!wizYesNo("  Write the settings anyway?", FALSE)) {
        cat("\nCancelled. Nothing was written.\n")
        return(invisible(NULL))
      }
    } else {
      cat("  Connected. ", format(people, big.mark = ","), " people in ",
          cdmSchema, ".\n", sep = "")
    }
  } else {
    cat("  Could not connect:\n    ", conditionMessage(conn), "\n\n", sep = "")
    if (!wizYesNo("Write the settings anyway, so you can fix them by hand?", FALSE)) {
      cat("\nCancelled. Nothing was written.\n")
      return(invisible(NULL))
    }
  }

  # ---------------------------------------------------------------------------
  wizHeading("6. Write")

  configLines <- c(
    "# --------------------------------------------------------------------------",
    "# Can-BUILD - settings for this machine",
    "#",
    "# Written by DatabaseSetup.R. Safe to edit by hand.",
    "# Not committed to git (see .gitignore).",
    "#",
    "# The database password is NOT here. It lives in .Renviron.",
    "# --------------------------------------------------------------------------",
    "",
    paste0("dbms: ", wizQuote(dbms)),
    paste0("server: ", wizQuote(server)),
    paste0("user: ", wizQuote(user)),
    paste0("cdmDatabaseSchema: ", wizQuote(cdmSchema)),
    paste0("workDatabaseSchema: ", wizQuote(workSchema)),
    paste0("cohortTableName: ", wizQuote(cohortTable)),
    paste0("databaseName: ", wizQuote(databaseName)),
    paste0("pathToDriver: ", wizQuote(driverFolder)),
    "minCellCount: 5"
  )

  renvLine <- if (nzchar(password)) {
    sprintf("%s=\"%s\"", var, password)
  } else NULL

  cat("\n  config.user.yml:\n\n")
  cat(paste0("    ", configLines, collapse = "\n"), "\n", sep = "")
  if (!is.null(renvLine)) {
    cat("\n  .Renviron (the password line is not printed here):\n\n")
    cat(sprintf("    %s=<your password>\n", var))
  }

  if (!wizYesNo("\n  Write these files?", TRUE)) {
    cat("\nCancelled. Nothing was written.\n")
    return(invisible(NULL))
  }

  writeLines(configLines, file.path(projectRoot, "config.user.yml"))
  cat("  Wrote config.user.yml\n")

  if (!is.null(renvLine)) {
    renviron <- file.path(projectRoot, ".Renviron")
    old <- if (file.exists(renviron)) readLines(renviron, warn = FALSE) else character(0)
    # replace an existing line for this variable, else append
    old <- old[!grepl(sprintf("^%s=", var), old)]
    writeLines(c(old, renvLine), renviron)
    cat("  Wrote .Renviron\n")
  }

  # ---------------------------------------------------------------------------
  wizHeading("Next")
  cat("R reads .Renviron only at startup, so RESTART R before running the study.\n\n")
  cat("Then:\n")
  cat("    source(\"DatabaseSetup.R\")     # confirm everything passes\n")
  cat("    source(\"ExecuteAnalyses.R\")   # run the study\n\n")

  invisible(TRUE)
}
