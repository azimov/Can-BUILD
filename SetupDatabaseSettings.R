################################################################################
# Can-BUILD - set up your database connection
#
# WHO THIS IS FOR
#   Anyone running this study against their own OMOP database.
#
# HOW TO USE IT
#   1. Open R (or RStudio) in this folder.
#   2. Type this line and press Enter:
#
#        source("SetupDatabaseSettings.R")
#
#   3. Answer the questions. Press Enter to accept the suggested value.
#
# WHAT IT DOES - all of it, nothing hidden
#   1. Asks you for your database details.
#   2. Asks the database for the number of people, so you can see it works.
#   3. Writes ONE file: config.local.yml, in this folder.
#   4. Stops. It does not run the study and does not send anything anywhere.
#
# WHAT IT SENDS
#   Nothing. The only network traffic is the connection you are configuring,
#   made with DatabaseConnector. There is no telemetry, no upload, no remote
#   logging. Read every line of this file - it is short on purpose.
#
# WHERE YOUR DETAILS GO
#   Into config.local.yml, in this folder. That file is listed in .gitignore,
#   so git will not commit it. Your password is NOT written to it; the file
#   reads the password from the OHDSI_DB_PASSWORD environment variable at run
#   time. You can read the whole file it writes - it is printed on screen below
#   and left on disk for you to check.
#
# WHY IT ASKS RATHER THAN TAKES ARGUMENTS
#   So that a human is in the loop. Nothing is configured from hidden defaults,
#   environment variables or command-line flags that you did not see.
################################################################################

# ------------------------------------------------------------------------------
# Small helpers - deliberately plain, so they are easy to read and audit.
# ------------------------------------------------------------------------------

# Ask a question. Returns the default if the user just presses Enter.
ask <- function(question, default = "") {
  if (nzchar(default)) {
    reply <- readline(sprintf("%s [%s]: ", question, default))
    if (!nzchar(reply)) return(default)
  } else {
    reply <- readline(sprintf("%s: ", question))
  }
  trimws(reply)
}

# Ask a yes/no question. Loops until it gets a clear answer.
ask_yes_no <- function(question, default = TRUE) {
  hint <- if (default) "Y/n" else "y/N"
  repeat {
    reply <- tolower(trimws(readline(sprintf("%s [%s]: ", question, hint))))
    if (!nzchar(reply)) return(default)
    if (reply %in% c("y", "yes")) return(TRUE)
    if (reply %in% c("n", "no")) return(FALSE)
    cat("  Please answer y or n.\n")
  }
}

# Ask for a password without echoing it to the screen where possible.
ask_password <- function(question) {
  if (requireNamespace("getPass", quietly = TRUE)) {
    return(getPass::getPass(question))
  }
  # Fall back: say clearly that the password will be visible as you type.
  cat("  (getPass is not installed, so the password will be visible as you type)\n")
  readline(paste0(question, ": "))
}

# Quote a value for the YAML file we are about to write.
yaml_quote <- function(x) {
  if (is.null(x) || !nzchar(x)) return("\"\"")
  x <- gsub("\\", "\\\\", x, fixed = TRUE)  # backslashes first (Windows paths)
  x <- gsub("\"", "\\\"", x, fixed = TRUE)
  sprintf("\"%s\"", x)
}

# Stop with a friendly message. No settings are written when this is called.
give_up <- function(...) {
  cat("\n")
  cat(strrep("!", 70), "\n")
  cat(paste0(...), "\n")
  cat("Nothing has been written. Run the script again when this is fixed.\n")
  cat(strrep("!", 70), "\n")
  stop("Setup stopped.", call. = FALSE)
}

# ------------------------------------------------------------------------------
# Section headings, so the user can follow where they are.
# ------------------------------------------------------------------------------
heading <- function(text) {
  cat("\n", strrep("-", 70), "\n", sep = "")
  cat(text, "\n")
  cat(strrep("-", 70), "\n", sep = "")
}

# ------------------------------------------------------------------------------
# The main routine.
# ------------------------------------------------------------------------------
setup_database_settings <- function(project_root = getwd()) {
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("  Can-BUILD - set up your database connection\n")
  cat(strrep("=", 70), "\n")
  cat("\n")
  cat("This will ask a few questions, test the connection, and write one file:\n")
  cat("  ", file.path(project_root, "config.local.yml"), "\n", sep = "")
  cat("\n")
  cat("That file is in .gitignore, so it is never committed. It will contain\n")
  cat("your server name and user name, but NOT your password.\n")
  cat("\n")

  if (!ask_yes_no("Are you ready to start?", default = TRUE)) {
    cat("\nOK - nothing was changed.\n")
    return(invisible(NULL))
  }

  # --------------------------------------------------------------------------
  # 1. Database type and driver
  # --------------------------------------------------------------------------
  heading("Step 1 of 4: Database type and driver")
  cat("Which database are you connecting to? Examples: postgresql, sql server,\n")
  cat("oracle, snowflake, redshift, bigquery.\n\n")

  dbms <- tolower(ask("Database type", "postgresql"))
  if (!nzchar(dbms)) give_up("A database type is required.")

  driver_folder <- Sys.getenv("DATABASECONNECTOR_JAR_FOLDER")
  driver_folder <- ask(
    "Folder containing the JDBC driver (.jar files)\n  (press Enter to use the folder above, or leave blank to download one now)",
    driver_folder
  )

  if (!nzchar(driver_folder)) {
    cat("\n  No driver folder given.\n")
    if (ask_yes_no(
      sprintf("  Download the %s JDBC driver now? It will be saved in this folder.", dbms),
      default = TRUE
    )) {
      cat("  Downloading...\n")
      driver_folder <- DatabaseConnector::downloadJdbcDrivers(
        dbms,
        pathToDriver = file.path(project_root, "jdbc")
      )
      cat("  Saved to: ", driver_folder, "\n", sep = "")
    } else {
      give_up("A JDBC driver is required. Set DATABASECONNECTOR_JAR_FOLDER and run again.")
    }
  }
  Sys.setenv(DATABASECONNECTOR_JAR_FOLDER = driver_folder)
  cat("  Driver folder: ", driver_folder, "\n", sep = "")

  # --------------------------------------------------------------------------
  # 2. Connecting
  # --------------------------------------------------------------------------
  heading("Step 2 of 4: Connecting")
  cat("Enter the connection details your database administrator gave you.\n")
  cat("The format of 'Server' depends on the database type; for PostgreSQL it\n")
  cat("is usually host/database, for example: db.example.org/cdm\n\n")

  server <- ask("Server", "")
  if (!nzchar(server)) give_up("A server is required.")

  user <- ask("User name", "")
  cat("\nPassword. If you press Enter, the password is read from the\n")
  cat("OHDSI_DB_PASSWORD environment variable instead, which is better for\n")
  cat("shared machines. Either way it is NOT written to any file.\n")
  password <- ask_password("Password")

  connection_details <- DatabaseConnector::createConnectionDetails(
    dbms = dbms,
    server = server,
    user = user,
    password = password,
    pathToDriver = driver_folder
  )

  cat("\n  Trying to connect...\n")
  connection <- tryCatch(
    DatabaseConnector::connect(connection_details),
    error = function(e) e
  )
  if (inherits(connection, "error")) {
    give_up(
      "Could not connect to the database.\n\n  ",
      conditionMessage(connection),
      "\n\nThings to check: the server name, the user name and password, whether\n",
      "your machine can reach the database, and that the driver matches the\n",
      "database type."
    )
  }
  cat("  Connected.\n")

  # --------------------------------------------------------------------------
  # 3. Schemas, and a check that the data is where you said it is
  # --------------------------------------------------------------------------
  heading("Step 3 of 4: Schemas")
  cat("The CDM schema is where your OMOP tables live. It must contain BOTH the\n")
  cat("patient data and the vocabulary (concept, concept_ancestor, ...).\n")
  cat("If yours are in separate schemas, ask for a schema or view that has both.\n\n")

  cdm_schema <- ask("CDM schema", "")
  if (!nzchar(cdm_schema)) {
    DatabaseConnector::disconnect(connection)
    give_up("A CDM schema is required.")
  }

  work_schema <- ask("Work schema (the study creates its cohort tables here)", "")
  if (!nzchar(work_schema)) {
    DatabaseConnector::disconnect(connection)
    give_up("A work schema is required.")
  }

  cohort_table <- ask("Name for the cohort table", "can_build_cohort")
  database_name <- ask("Short name for this database (used to name the results folder)", "MY_SITE")

  cat("\n  Checking ", cdm_schema, "...\n", sep = "")

  people <- tryCatch(
    DatabaseConnector::querySql(
      connection,
      sprintf("SELECT COUNT(*) AS INVALUE FROM %s.person;", cdm_schema),
      snakeCaseToCamelCase = TRUE
    )[[1]],
    error = function(e) e
  )
  if (inherits(people, "error")) {
    DatabaseConnector::disconnect(connection)
    give_up(
      "Could not read ", cdm_schema, ".person.\n\n  ",
      conditionMessage(people),
      "\n\nCheck the schema name, and that your user can read it."
    )
  }
  cat("  It worked: there are ", format(people, big.mark = ","), " people in ", cdm_schema, ".\n", sep = "")

  # Vocabulary check - the study cannot run without it.
  vocabulary <- tryCatch(
    DatabaseConnector::querySql(
      connection,
      sprintf("SELECT COUNT(*) AS INVALUE FROM %s.concept;", cdm_schema),
      snakeCaseToCamelCase = TRUE
    )[[1]],
    error = function(e) e
  )
  if (inherits(vocabulary, "error")) {
    cat("\n  WARNING: could not read ", cdm_schema, ".concept.\n", sep = "")
    cat("  The study needs the vocabulary in the same schema as the patient data.\n")
    if (!ask_yes_no("  Continue anyway?", default = FALSE)) {
      DatabaseConnector::disconnect(connection)
      give_up("Stopped at your request.")
    }
  } else {
    cat("  Vocabulary found: ", format(vocabulary, big.mark = ","), " concepts.\n", sep = "")
  }

  DatabaseConnector::disconnect(connection)
  cat("  Disconnected.\n")

  # --------------------------------------------------------------------------
  # 4. Write the file
  # --------------------------------------------------------------------------
  heading("Step 4 of 4: Writing your settings")

  config_file <- file.path(project_root, "config.local.yml")

  if (file.exists(config_file)) {
    cat("  A settings file already exists:\n    ", config_file, "\n\n", sep = "")
    if (!ask_yes_no("  Replace it?", default = FALSE)) {
      cat("\n  Left the existing file alone. Nothing was changed.\n")
      return(invisible(config_file))
    }
  }

  lines <- c(
    "# --------------------------------------------------------------------------",
    "# Can-BUILD - database settings for this machine",
    "#",
    "# Written by SetupDatabaseSettings.R. Safe to edit by hand.",
    "# This file is listed in .gitignore and is NOT committed to git.",
    "#",
    "# Your password is not in this file. The password is read from the",
    "# OHDSI_DB_PASSWORD environment variable when the study runs.",
    "# --------------------------------------------------------------------------",
    "",
    "local:",
    paste0("  cdmDatabaseSchema: ", yaml_quote(cdm_schema)),
    paste0("  workDatabaseSchema: ", yaml_quote(work_schema)),
    paste0("  cohortTableName: ", yaml_quote(cohort_table)),
    paste0("  databaseName: ", yaml_quote(database_name)),
    "  minCellCount: 5",
    paste0("  pathToDriver: ", yaml_quote(driver_folder)),
    "",
    "  connectionDetails: !expr |",
    "    DatabaseConnector::createConnectionDetails(",
    paste0("      dbms = ", yaml_quote(dbms), ","),
    paste0("      server = ", yaml_quote(server), ","),
    paste0("      user = ", yaml_quote(user), ","),
    "      password = Sys.getenv(\"OHDSI_DB_PASSWORD\"),",
    paste0("      pathToDriver = ", yaml_quote(driver_folder)),
    "    )"
  )

  writeLines(lines, config_file)

  cat("\n  Written to: ", config_file, "\n", sep = "")
  cat("\n  This is everything in the file - please read it:\n\n")
  cat(paste0("    ", lines, collapse = "\n"), "\n", sep = "")
  cat("\n")

  # Make sure the password is available for the run.
  if (!nzchar(password)) {
    cat("  You did not type a password, so the file uses OHDSI_DB_PASSWORD.\n")
    cat("  Set it before running the study, in the same R session:\n\n")
    cat("    Sys.setenv(OHDSI_DB_PASSWORD = \"your password\")\n\n")
  } else {
    cat("  Your password was used for the test above but was NOT saved.\n")
    cat("  Set it in the R session before running the study:\n\n")
    cat("    Sys.setenv(OHDSI_DB_PASSWORD = \"your password\")\n\n")
    cat("  (Or, on a machine where you are happy to store it, put it into\n")
    cat("   config.local.yml yourself - the file is not committed.)\n\n")
  }

  cat(strrep("=", 70), "\n")
  cat("  Done.\n")
  cat("\n")
  cat("  Next, run the study:\n")
  cat("    source(\"ExecuteAnalyses.R\")\n")
  cat("\n")
  cat("  Results will appear in results/", database_name, "/\n", sep = "")
  cat(strrep("=", 70), "\n")

  invisible(config_file)
}

# ------------------------------------------------------------------------------
# Run it. If this script is sourced from a script rather than typed by a
# person, nothing happens: the checks below make that explicit.
# ------------------------------------------------------------------------------
if (!interactive()) {
  cat("\n")
  cat("SetupDatabaseSettings.R needs to be run by a person in an interactive R\n")
  cat("session, because it asks questions. Nothing has been done.\n")
  cat("\n")
  cat("Open R or RStudio in this folder and run:\n")
  cat("    source(\"SetupDatabaseSettings.R\")\n")
  cat("\n")
} else {
  setup_database_settings()
}
