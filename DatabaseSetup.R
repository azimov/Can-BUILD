################################################################################
# Check your database setup
#
# Run this from the project root:
#
#   source("DatabaseSetup.R")
#
# It does NOT ask you questions. It reads the settings you have, tries the
# connection, and tells you exactly what is wrong and how to fix it.
#
# If it reports something missing and you would rather be walked through it,
# run the wizard instead:
#
#   source("DatabaseSetup.R")    # then choose the wizard when offered
#
# CHECKS, in order:
#   1. Java can be started and is new enough
#   2. A settings file exists (config.user.yml)
#   3. The password is available from the environment
#   4. The JDBC driver is present
#   5. The database connection works
#   6. The CDM schema is readable, with a plausible number of people
#   7. The vocabulary is in the same schema
#   8. The work schema exists and is writable
#
# WHAT IT DOES NOT DO
#   It does not install anything, does not write to your CDM, and does not send
#   anything anywhere. The only network traffic is the database connection you
#   are configuring, which you asked it to test.
################################################################################

source(file.path("scriptsForStudyDesigner", "getStudyConfig.R"))
source(file.path("scriptsForStudyDesigner", "DatabaseWizard.R"))

# ------------------------------------------------------------------------------
# Tiny check runner: each check returns OK / WARN / FAIL plus advice.
# ------------------------------------------------------------------------------
newResult <- function(status, message, advice = NULL) {
  list(status = status, message = message, advice = advice)
}
ok   <- function(msg) newResult("OK", msg)
warn <- function(msg, advice = NULL) newResult("WARN", msg, advice)
fail <- function(msg, advice = NULL) newResult("FAIL", msg, advice)

symbol <- function(status) {
  switch(status, OK = "[ OK ]", WARN = "[WARN]", FAIL = "[FAIL]")
}

reportResult <- function(title, result) {
  cat(sprintf("%s %s\n", symbol(result$status), title))
  if (nzchar(result$message)) {
    for (line in strsplit(result$message, "\n", fixed = TRUE)[[1]]) {
      cat("        ", line, "\n", sep = "")
    }
  }
  if (!is.null(result$advice) && length(result$advice) > 0) {
    cat("\n")
    for (element in result$advice) {
      for (line in strsplit(element, "\n", fixed = TRUE)[[1]]) {
        cat("   ", line, "\n", sep = "")
      }
    }
    cat("\n")
  }
  invisible(result$status)
}

# ------------------------------------------------------------------------------
# 1. Java
# ------------------------------------------------------------------------------
checkJava <- function() {
  started <- tryCatch({
    rJava::.jinit()
    TRUE
  }, error = function(e) FALSE)

  if (!started) {
    return(fail(
      "Java could not be started.",
      paste(
        "Install a JDK (17 or newer) and tell R where it is:",
        "",
        "  export JAVA_HOME=/path/to/jdk-17",
        "",
        "Then restart R and run this again.",

        sep = "\n"
      )
    ))
  }

  version <- tryCatch(
    rJava::.jcall("java/lang/System", "S", "getProperty", "java.version"),
    error = function(e) NA_character_
  )
  major <- suppressWarnings(as.integer(strsplit(version, "[._-]")[[1]][1]))

  if (!is.na(major) && major < 11) {
    return(fail(
      sprintf("Java %s is too old.", version),
      paste(
        "The database packages need Java 17 or newer.",
        "Install one, point JAVA_HOME at it, restart R.",

        sep = "\n"
      )
    ))
  }
  ok(sprintf("Java %s", version))
}

# ------------------------------------------------------------------------------
# 2. Settings file
# ------------------------------------------------------------------------------
checkSettings <- function() {
  path <- file.path(getwd(), "config.user.yml")
  if (!file.exists(path)) {
    return(fail(
      "No config.user.yml found.",
      paste(
        "Create one, either:",
        "",
        "  * run the wizard:   source(\"DatabaseSetup.R\")  (choose 'wizard')",
        "  * or copy the example and edit it:",
        "      cp config.user.example.yml config.user.yml",
        "",
        "It is gitignored, so your settings stay on your machine.",

        sep = "\n"
      )
    ))
  }

  parsed <- tryCatch(
    yaml::read_yaml(path, eval.expr = TRUE),
    error = function(e) e
  )
  if (inherits(parsed, "error")) {
    return(fail(
      "config.user.yml could not be read.",
      paste("The YAML is malformed:", conditionMessage(parsed)))
    )
  }
  ok(path)
}

# ------------------------------------------------------------------------------
# 3. Password
# ------------------------------------------------------------------------------
checkPassword <- function(db) {
  var <- db$passwordVariable
  if (nzchar(db$password)) {
    return(ok(sprintf("Password found in %s", var)))
  }

  # A project .Renviron only takes effect when R starts, so if the file exists
  # and mentions the variable, the user probably just needs to restart R.
  renviron <- file.path(getwd(), ".Renviron")
  inFile <- file.exists(renviron) &&
    any(grepl(sprintf("^%s=", var), readLines(renviron, warn = FALSE)))

  advice <- if (inFile) {
    paste(
      sprintf("%s IS set in .Renviron, but R reads that file only at startup.", var),
      "Restart R (Session > Restart R in RStudio) and run this again.",
      sep = "\n"
    )
  } else {
    paste(
      "Set it in .Renviron, which is not committed to git:",
      "",
      sprintf('  %s="your password"', var),
      "",
      "To open that file:",
      "  usethis::edit_r_environ(scope = \"project\")   # if usethis is installed",
      "  or edit .Renviron in this folder by hand.",
      "",
      "Then restart R - .Renviron is only read at startup.",
      sep = "\n"
    )
  }
  fail(sprintf("%s is not set.", var), advice)
}

# ------------------------------------------------------------------------------
# 4. JDBC driver
# ------------------------------------------------------------------------------
checkDriver <- function(db) {
  folder <- db$pathToDriver
  if (!nzchar(folder)) {
    return(fail(
      "No JDBC driver folder set (pathToDriver).",
      paste(
        "Either add it to config.user.yml:",
        "  pathToDriver: \"/path/to/jdbc\"",
        "",
        "or download a driver once:",
        sprintf('  DatabaseConnector::downloadJdbcDrivers("%s")', db$dbms),

        sep = "\n"
      )
    ))
  }
  if (!dir.exists(folder)) {
    return(fail(
      sprintf("Driver folder does not exist: %s", folder),
      "Correct pathToDriver in config.user.yml."
    ))
  }
  jars <- list.files(folder, pattern = "[.]jar$")
  if (length(jars) == 0) {
    return(fail(
      sprintf("No .jar files in %s", folder),
      sprintf('Download one: DatabaseConnector::downloadJdbcDrivers("%s")', db$dbms)
    ))
  }
  ok(sprintf("%d driver file(s) in %s", length(jars), folder))
}

# ------------------------------------------------------------------------------
# 5-8. Connection and schema checks
# ------------------------------------------------------------------------------
checkDatabase <- function(db) {
  missing <- character()
  for (field in c("server", "user", "cdmDatabaseSchema", "workDatabaseSchema")) {
    if (!nzchar(db[[field]])) missing <- c(missing, field)
  }
  if (length(missing)) {
    return(list(
      connection = fail(
        sprintf("These settings are empty: %s", paste(missing, collapse = ", ")),
        "Fill them in config.user.yml, or run the wizard."
      )
    ))
  }

  details <- studyConnectionDetails(db)
  conn <- tryCatch(
    DatabaseConnector::connect(details),
    error = function(e) e
  )
  if (inherits(conn, "error")) {
    return(list(
      connection = fail(
        "Could not connect.",
        paste(
          conditionMessage(conn),
          "",
          "Check the server, user and password. If the message mentions",
          "'ByteBuffer' the problem is Java, not the database.",

          sep = "\n"
        )
      )
    ))
  }
  on.exit(DatabaseConnector::disconnect(conn), add = TRUE)

  results <- list(connection = ok(sprintf("Connected to %s", db$server)))

  # Can we read the CDM?
  people <- tryCatch(
    DatabaseConnector::querySql(
      conn, sprintf("SELECT COUNT(*) AS N FROM %s.person;", db$cdmDatabaseSchema)
    )[[1]],
    error = function(e) e
  )
  if (inherits(people, "error")) {
    results$cdm <- fail(
      sprintf("Could not read %s.person", db$cdmDatabaseSchema),
      paste(
        conditionMessage(people),
        "",
        "Check cdmDatabaseSchema in config.user.yml and that your user can read it.",

        sep = "\n"
      )
    )
    return(results)
  }
  if (people == 0) {
    results$cdm <- warn(
      sprintf("%s.person is empty", db$cdmDatabaseSchema),
      "The study will run but produce nothing."
    )
  } else {
    results$cdm <- ok(sprintf("%s: %s people", db$cdmDatabaseSchema,
                              format(people, big.mark = ",")))
  }

  # Vocabulary in the same schema?
  concepts <- tryCatch(
    DatabaseConnector::querySql(
      conn, sprintf("SELECT COUNT(*) AS N FROM %s.concept;", db$cdmDatabaseSchema)
    )[[1]],
    error = function(e) e
  )
  if (inherits(concepts, "error")) {
    results$vocabulary <- fail(
      "No vocabulary in the CDM schema.",
      paste(
        sprintf("%s.concept could not be read.", db$cdmDatabaseSchema),
        "",
        "The study needs concept, concept_ancestor and concept_relationship",
        "in the same schema as the clinical tables. If your vocabulary lives",
        "elsewhere, point cdmDatabaseSchema at a schema (or view layer) that",
        "exposes both.",

        sep = "\n"
      )
    )
  } else {
    results$vocabulary <- ok(
      sprintf("%s: %s concepts", db$cdmDatabaseSchema, format(concepts, big.mark = ",")))
  }

  # Work schema writable?
  writable <- tryCatch({
    name <- sprintf("%s.__can_build_write_test", db$workDatabaseSchema)
    DatabaseConnector::executeSql(conn, sprintf("CREATE TABLE %s (x INT);", name),
                                  progressBar = FALSE, reportOverallTime = FALSE)
    DatabaseConnector::executeSql(conn, sprintf("DROP TABLE %s;", name),
                                  progressBar = FALSE, reportOverallTime = FALSE)
    TRUE
  }, error = function(e) e)

  if (inherits(writable, "error")) {
    results$work <- fail(
      sprintf("%s is not writable", db$workDatabaseSchema),
      paste(
        conditionMessage(writable),
        "",
        "The study creates its cohort tables in this schema. Check the name and",
        "that your user has CREATE permission there.",

        sep = "\n"
      )
    )
  } else {
    results$work <- ok(sprintf("%s is writable", db$workDatabaseSchema))
  }

  results
}

# ------------------------------------------------------------------------------
# The check
# ------------------------------------------------------------------------------
runStudyChecks <- function(quiet = FALSE) {
  if (!quiet) {
    cat("\n", strrep("=", 70), "\n", sep = "")
    cat("  Can-BUILD - database setup check\n")
    cat(strrep("=", 70), "\n\n", sep = "")
  }

  results <- list()
  results$java <- checkJava()
  reportResult("Java", results$java)
  if (results$java$status == "FAIL") {
    return(invisible(toSummary(results)))
  }

  results$settings <- checkSettings()
  reportResult("Settings file", results$settings)

  db <- studyDatabaseSettings()
  results$password <- checkPassword(db)
  reportResult("Password", results$password)

  results$driver <- checkDriver(db)
  reportResult("JDBC driver", results$driver)

  if (results$settings$status == "OK" &&
      results$password$status == "OK" &&
      results$driver$status == "OK") {
    dbResults <- checkDatabase(db)
    for (nm in names(dbResults)) {
      label <- switch(nm,
        connection = "Connection",
        cdm = "CDM schema",
        vocabulary = "Vocabulary",
        work = "Work schema",
        nm)
      results[[nm]] <- dbResults[[nm]]
      reportResult(label, dbResults[[nm]])
    }
  } else {
    cat("\nSkipping connection checks until the problems above are fixed.\n")
  }

  invisible(toSummary(results))
}

toSummary <- function(results) {
  statuses <- vapply(results, function(r) r$status, character(1))
  fails <- names(statuses)[statuses == "FAIL"]
  warns <- names(statuses)[statuses == "WARN"]

  cat("\n", strrep("-", 70), "\n", sep = "")
  if (length(fails) == 0 && length(warns) == 0) {
    cat("  Everything checks out. You can run the study:\n")
    cat("    source(\"ExecuteAnalyses.R\")\n")
  } else if (length(fails) == 0) {
    cat("  Ready, with warnings. You can run the study:\n")
    cat("    source(\"ExecuteAnalyses.R\")\n")
  } else {
    cat("  Not ready yet. Fix the items marked [FAIL] above.\n")
    cat("  Missing or wrong: ", paste(fails, collapse = ", "), "\n", sep = "")
    cat("\n  Prefer to be walked through it? Run the wizard:\n")
    cat("    source(\"DatabaseSetup.R\", echo = FALSE); runDatabaseWizard()\n")
  }
  cat(strrep("-", 70), "\n\n", sep = "")

  invisible(list(results = results, ready = length(fails) == 0))
}

# ------------------------------------------------------------------------------
# Entry point
# ------------------------------------------------------------------------------
runSetup <- function(askAboutWizard = TRUE) {
  # Always show the current state first.
  summary <- runStudyChecks()

  # Only offer the wizard when something needs fixing.
  if (!askAboutWizard || summary$ready) {
    return(invisible(summary))
  }

  cat("\nPrefer to be walked through it instead? Run the wizard:\n")
  cat("    runDatabaseWizard()\n\n")
  answer <- readline("Run the wizard now? (y/n): ")
  if (tolower(trimws(answer)) %in% c("y", "yes")) {
    runDatabaseWizard()
    cat("\nRe-checking after the wizard...\n")
    return(invisible(runStudyChecks()))
  }
  invisible(summary)
}

if (interactive()) {
  runSetup()
} else {
  cat("\nDatabaseSetup.R is interactive. Nothing was run.\n")
  cat("Run it from R or RStudio in this folder:\n")
  cat("    source(\"DatabaseSetup.R\")\n\n")
}
