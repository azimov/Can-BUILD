################################################################################
# Set up your database settings for this study
#
# Run this once, from the project root, in an interactive R session:
#
#   source("scriptsForStudyDesigner/SetupDatabaseSettings.R")
#
# It asks for your database connection details, tests them, writes
# config.local.yml (gitignored, so your credentials never leave your machine),
# and checks that the study's cohorts are present in your CDM.
#
# Everything is optional: pressing Enter keeps the value in [brackets].
################################################################################

ask <- function(prompt, default = "") {
  if (!interactive()) {
    return(default)
  }
  reply <- readline(sprintf("%s [%s]: ", prompt, default))
  if (!nzchar(reply)) default else reply
}

askYesNo <- function(prompt, default = TRUE) {
  if (!interactive()) {
    return(default)
  }
  reply <- tolower(trimws(ask(paste0(prompt, " (y/n)"), if (default) "y" else "n")))
  reply %in% c("y", "yes", "true", "t")
}

setupDatabaseSettings <- function(projectRootFolder = getwd()) {
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("Setting up database settings for the Can-BUILD study\n")
  cat(strrep("=", 70), "\n\n")

  cat("You will need:\n")
  cat("  - the schema that holds your OMOP CDM (clinical tables + vocabulary)\n")
  cat("  - a writable schema for the study to create cohort tables in\n")
  cat("  - a database user that can read the CDM and write to that schema\n\n")

  # --- Java ----------------------------------------------------------------
  cat("--- Java ------------------------------------------------------------\n")
  cat("DatabaseConnector needs Java 11 or newer.\n")
  currentJava <- Sys.getenv("JAVA_HOME")
  javaHome <- ask("JAVA_HOME", currentJava)
  if (nzchar(javaHome)) {
    Sys.setenv(JAVA_HOME = javaHome)
  }
  cat("\n")

  # --- JDBC driver ---------------------------------------------------------
  cat("--- JDBC driver -----------------------------------------------------\n")
  dbms <- ask("Database type (postgresql, sql server, oracle, snowflake, ...)", "postgresql")
  driverFolder <- Sys.getenv("DATABASECONNECTOR_JAR_FOLDER")
  if (!nzchar(driverFolder)) {
    driverFolder <- ask(
      "Folder holding the JDBC driver\n  (leave blank to download one now)",
      ""
    )
  }
  if (!nzchar(driverFolder)) {
    if (askYesNo(sprintf("Download the %s JDBC driver now?", dbms))) {
      driverFolder <- DatabaseConnector::downloadJdbcDrivers(dbms)
    } else {
      stop("A JDBC driver is required. Set DATABASECONNECTOR_JAR_FOLDER and re-run.")
    }
  }
  Sys.setenv(DATABASECONNECTOR_JAR_FOLDER = driverFolder)
  cat("\n")

  # --- Connection ----------------------------------------------------------
  cat("--- Connection details ----------------------------------------------\n")
  server <- ask("Server", "")
  user <- ask("User", "")
  cat("Password: leave blank to use the OHDSI_DB_PASSWORD environment variable\n")
  cat("  (recommended: keyring, e.g. keyring::key_get(\"ohdsi\"))\n")
  password <- ask("Password", "")
  if (!nzchar(password)) {
    password <- Sys.getenv("OHDSI_DB_PASSWORD")
  }
  connectionDetails <- DatabaseConnector::createConnectionDetails(
    dbms = dbms,
    server = server,
    user = user,
    password = password,
    pathToDriver = driverFolder
  )

  cat("\n--- Testing the connection ------------------------------------------\n")
  conn <- tryCatch(
    DatabaseConnector::connect(connectionDetails),
    error = function(e) {
      stop(
        "Could not connect to the database:\n  ", conditionMessage(e),
        "\n\nNo settings were written. Fix the details and re-run.",
        call. = FALSE
      )
    }
  )
  on.exit(DatabaseConnector::disconnect(conn), add = TRUE)
  cat("Connected.\n\n")

  # --- Schemas -------------------------------------------------------------
  cat("--- Schemas ---------------------------------------------------------\n")
  cdmDatabaseSchema <- ask("CDM schema (clinical tables + vocabulary)", "")
  workDatabaseSchema <- ask("Work schema (writable; cohort tables go here)", "")
  cohortTableName <- ask("Cohort table name", "can_build_cohort")
  databaseName <- ask("Short database name (used as a results folder)", "")

  cat("\n--- Checking the CDM ------------------------------------------------\n")
  check <- tryCatch({
    DatabaseConnector::querySql(
      conn,
      sprintf("SELECT COUNT(*) AS n FROM %s.person;", cdmDatabaseSchema),
      snakeCaseToCamelCase = TRUE
    )
  }, error = function(e) NULL)

  if (is.null(check)) {
    stop(
      "Could not read ", cdmDatabaseSchema, ".person. Check the CDM schema name ",
      "and that your user can read it.\nNo settings were written.",
      call. = FALSE
    )
  }
  cat("  persons in the CDM: ", format(check$n, big.mark = ","), "\n", sep = "")

  required <- c("person", "observation_period", "visit_occurrence",
                "condition_occurrence", "drug_exposure", "concept",
                "concept_ancestor")
  present <- tryCatch({
    DatabaseConnector::querySql(
      conn,
      sprintf(
        "SELECT LOWER(table_name) AS t FROM information_schema.tables WHERE LOWER(table_schema) = LOWER('%s');",
        cdmDatabaseSchema
      )
    )[[1]]
  }, error = function(e) character(0))

  if (length(present) > 0) {
    missingTables <- setdiff(required, present)
    if (length(missingTables) > 0) {
      cat("  WARNING: these expected tables were not found in ", cdmDatabaseSchema, ":\n", sep = "")
      cat("    ", paste(missingTables, collapse = ", "), "\n", sep = "")
      cat("  If your vocabulary lives in a separate schema, that is fine - set\n")
      cat("  cdmDatabaseSchema to a schema (or view layer) that exposes both.\n")
    }
  }
  cat("\n")

  # --- Write config.local.yml ---------------------------------------------
  configPath <- file.path(projectRootFolder, "config.local.yml")
  overwrite <- TRUE
  if (file.exists(configPath)) {
    overwrite <- askYesNo(
      sprintf("%s already exists. Overwrite it?", basename(configPath)),
      default = FALSE
    )
  }
  if (!overwrite) {
    cat("Left ", basename(configPath), " unchanged.\n", sep = "")
    return(invisible(configPath))
  }

  writeLines(
    c(
      "# Generated by scriptsForStudyDesigner/SetupDatabaseSettings.R",
      "# NOT checked in to git - see .gitignore.",
      "",
      "local:",
      sprintf("  cdmDatabaseSchema: %s", yamlQuote(cdmDatabaseSchema)),
      sprintf("  workDatabaseSchema: %s", yamlQuote(workDatabaseSchema)),
      sprintf("  cohortTableName: %s", yamlQuote(cohortTableName)),
      sprintf("  databaseName: %s", yamlQuote(databaseName)),
      "  minCellCount: 5",
      sprintf("  javaHome: %s", yamlQuote(javaHome)),
      sprintf("  pathToDriver: %s", yamlQuote(driverFolder)),
      "",
      "  connectionDetails: !expr |",
      "    DatabaseConnector::createConnectionDetails(",
      sprintf("      dbms = %s,", yamlQuote(dbms)),
      sprintf("      server = %s,", yamlQuote(server)),
      sprintf("      user = %s,", yamlQuote(user)),
      "      password = Sys.getenv(\"OHDSI_DB_PASSWORD\"),",
      sprintf("      pathToDriver = %s", yamlQuote(driverFolder)),
      "    )"
    ),
    configPath
  )
  cat("Settings written to ", configPath, "\n", sep = "")
  if (!nzchar(password)) {
    cat("No password was given, so the file reads it from OHDSI_DB_PASSWORD.\n")
    cat("Set it before running the study:\n")
    cat("  Sys.setenv(OHDSI_DB_PASSWORD = keyring::key_get(\"ohdsi\"))\n")
  } else {
    cat("The password was NOT written to the file: it is read from\n")
    cat("OHDSI_DB_PASSWORD at run time. Export it in this session before running\n")
    cat("the study:\n")
    cat("  Sys.setenv(OHDSI_DB_PASSWORD = \"<your password>\")\n")
    cat("Passwordless (e.g. Kerberos / integrated auth) databases can delete the\n")
    cat("password line from the file.\n")
  }
  cat("\n")

  cat(strrep("-", 70), "\n")
  cat("Next: run the study from the project root:\n")
  cat("  source(\"ExecuteAnalyses.R\")\n")
  cat(strrep("-", 70), "\n")

  invisible(configPath)
}

yamlQuote <- function(x) {
  if (is.null(x) || !nzchar(x)) return("\"\"")
  # Escape backslashes first (Windows paths), then double quotes.
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub("\"", "\\\"", x, fixed = TRUE)
  sprintf("\"%s\"", x)
}

setupDatabaseSettings()
