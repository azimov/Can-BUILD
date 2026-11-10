################################################################################
# Study configuration
#
# HOW SETTINGS ARE STORED
# -----------------------
#   config.yml          checked in. Study defaults: schema names, folders, etc.
#   config.user.yml     NOT checked in. YOUR values for this machine.
#   .Renviron           NOT checked in. Secrets only (the database password).
#
# config.user.yml overrides config.yml key by key; anything you leave out falls
# back to the default. The password is never in either YAML file - it comes from
# the environment, so it cannot be committed by accident.
#
# Both untracked files are produced by DatabaseSetup.R:
#
#   source("DatabaseSetup.R")   # check your setup, or run the wizard
#
# WHAT THIS FILE PROVIDES
# -----------------------
#   getStudyConfig()        the merged settings
#   studyDatabaseSettings() just the database-related ones
#   passwordVariableName()  which environment variable holds the password
#
# Nothing here connects to a database. DatabaseSetup.R does that.
################################################################################

# `%||%` without depending on rlang (R >= 4.4 has it, but be explicit).
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x
}

# The environment variable that holds the database password.
#
# A named variable beats a single shared one: a site can keep several passwords
# side by side (OHDSI_PASSWORD_MYHOSPITAL, OHDSI_PASSWORD_LAB, ...).
passwordVariableName <- function(databaseName = NULL) {
  if (!is.null(databaseName) && nzchar(databaseName)) {
    nm <- sprintf("OHDSI_PASSWORD_%s",
                  gsub("[^A-Za-z0-9]", "_", toupper(databaseName)))
    if (nzchar(Sys.getenv(nm))) {
      return(nm)
    }
  }
  "OHDSI_DB_PASSWORD"
}

# Read one YAML file, returning an empty list if it is missing or empty.
readYamlFile <- function(path) {
  if (!file.exists(path)) {
    return(list())
  }
  value <- tryCatch(
    yaml::read_yaml(path, eval.expr = TRUE),
    error = function(e) {
      stop("Could not read ", path, ":\n  ", conditionMessage(e), call. = FALSE)
    }
  )
  if (is.null(value)) list() else value
}

# Drop profile wrappers: a user file may be written flat, or nested under
# `default:` or `local:`.
unwrapProfile <- function(value, profile = Sys.getenv("R_CONFIG_ACTIVE", "default")) {
  if (!is.list(value)) {
    return(list())
  }
  for (key in c("default", profile, "local")) {
    if (is.list(value[[key]])) {
      return(value[[key]])
    }
  }
  value
}

# The merged configuration: config.yml with config.user.yml on top.
getStudyConfig <- function(projectRootFolder = getwd()) {
  base <- unwrapProfile(readYamlFile(file.path(projectRootFolder, "config.yml")))
  user <- unwrapProfile(readYamlFile(file.path(projectRootFolder, "config.user.yml")))

  merged <- utils::modifyList(as.list(base), as.list(user))
  merged$projectRootFolder <- projectRootFolder
  merged
}

# The database settings, with defaults for anything not set, plus the password
# resolved from the environment.
studyDatabaseSettings <- function(config = getStudyConfig()) {
  db <- list(
    dbms = config$dbms %||% "postgresql",
    server = config$server %||% "",
    port = config$port %||% NA_integer_,
    user = config$user %||% "",
    cdmDatabaseSchema = config$cdmDatabaseSchema %||% "",
    workDatabaseSchema = config$workDatabaseSchema %||% "",
    cohortTableName = config$cohortTableName %||% "can_build_cohort",
    databaseName = config$databaseName %||% "",
    pathToDriver = config$pathToDriver %||% Sys.getenv("DATABASECONNECTOR_JAR_FOLDER"),
    minCellCount = config$minCellCount %||% 5
  )
  var <- passwordVariableName(db$databaseName)
  db$passwordVariable <- var
  db$password <- Sys.getenv(var)
  db
}

# Build ConnectionDetails from the settings. The password is looked up by
# DatabaseConnector at connect time, so setting the variable is enough.
studyConnectionDetails <- function(db = studyDatabaseSettings(),
                                   config = getStudyConfig()) {
  DatabaseConnector::createConnectionDetails(
    dbms = db$dbms,
    server = db$server,
    port = if (is.na(db$port)) NULL else db$port,
    user = db$user,
    password = Sys.getenv(db$passwordVariable, unset = ""),
    pathToDriver = db$pathToDriver,
    connectionString = if (nzchar(config$connectionString %||% ""))
      config$connectionString else NULL
  )
}

