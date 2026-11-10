# -------------------------------------------------------
#                     PLEASE READ
# -------------------------------------------------------
#
# You must call "renv::restore()" and follow the prompts
# to install all of the necessary R libraries to run this
# project. This is a one-time operation that you must do
# before running any code.
#
# !!! PLEASE RESTART R AFTER RUNNING renv::restore() !!!
#
# -------------------------------------------------------
renv::restore()

# ENVIRONMENT SETTINGS NEEDED FOR RUNNING STUDY ------------
Sys.setenv("_JAVA_OPTIONS" = "-Xmx4g") # Sets the Java maximum heap space to 4GB
Sys.setenv("VROOM_THREADS" = 1) # Sets the number of threads to 1 to avoid deadlocks on file system

##=========== START OF INPUTS ==========
# Study configuration ---------------------------------------------------------
# All machine-specific values come from the config files, not from this script:
#
#   config.yml         checked in. Shared settings (study name, folders, ...).
#   config.local.yml   NOT checked in. Your database host, credentials, schema
#                      names, Java path and JDBC driver folder. Copy
#                      config.local.example.yml to config.local.yml and edit it.
#
# Anything you do not set in config.local.yml falls back to config.yml. Values
# can also be supplied with OHDSI_* environment variables, which win over both.
source("scriptsForStudyDesigner/getStudyConfig.R")
config <- getStudyConfig()

cdmDatabaseSchema <- Sys.getenv("OHDSI_CDM_SCHEMA", config$cdmDatabaseSchema)
workDatabaseSchema <- Sys.getenv("OHDSI_WORK_SCHEMA", config$workDatabaseSchema)
cohortTableName <- Sys.getenv("OHDSI_COHORT_TABLE", config$cohortTableName)
databaseName <- Sys.getenv("OHDSI_DATABASE_NAME", config$databaseName)
minCellCount <- as.integer(Sys.getenv("OHDSI_MIN_CELL_COUNT", config$minCellCount))
resultsFolder <- config$resultFolder # Where the output files will be written
workFolder <- config$workFolder # Where the intermediate work files will be written

# Java and the JDBC driver. DatabaseConnector 8 needs Java 11+ and the driver
# folder passed explicitly.
if (nzchar(config$javaHome %||% "")) {
  Sys.setenv(JAVA_HOME = config$javaHome)
}
options(java.home = Sys.getenv("JAVA_HOME", config$javaHome %||% ""))
Sys.setenv(DATABASECONNECTOR_JAR_FOLDER = config$pathToDriver %||% "")

# Connection details.
connectionDetails <- if (!is.null(config$connectionDetails)) {
  config$connectionDetails
} else {
  DatabaseConnector::createConnectionDetails(
    dbms = Sys.getenv("OHDSI_DBMS", "postgresql"),
    server = Sys.getenv("OHDSI_SERVER", "127.0.0.1/postgres"),
    port = as.integer(Sys.getenv("OHDSI_PORT", "5432")),
    user = Sys.getenv("OHDSI_USER", "postgres"),
    password = Sys.getenv("OHDSI_PASSWORD", ""),
    pathToDriver = config$pathToDriver %||% ""
  )
}

# You can use this snippet to test your connection
#conn <- DatabaseConnector::connect(connectionDetails)
#DatabaseConnector::disconnect(conn)

##=========== END OF INPUTS ==========

##################################
# DO NOT MODIFY BELOW THIS POINT
##################################
resultsFolder <- file.path(resultsFolder, databaseName)
workFolder <- file.path(workFolder, databaseName)
cohortTableNames <- CohortGenerator::getCohortTableNames(cohortTable = cohortTableName)

analysisSpecifications <- ParallelLogger::loadSettingsFromJson(
  fileName = file.path(config$projectRootFolder, "inst", config$studySpecificationFileName)
)

executionSettings <- Strategus::createCdmExecutionSettings(
  workDatabaseSchema = workDatabaseSchema,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortTableNames = cohortTableNames,
  workFolder = workFolder,
  resultsFolder = resultsFolder,
  minCellCount = minCellCount
  # IF YOU NEED TO RE-RUN A STUDY BUT ONLY WANT TO RUN SPECIFIC MODULES,
  # USE modulesToExecute:
  # , modulesToExecute = c("CohortGeneratorModule", "CharacterizationModule")
)

if (!dir.exists(resultsFolder)) {
  dir.create(resultsFolder, recursive = T)
}

if (!dir.exists(workFolder)) {
  dir.create(workFolder, recursive = T)
}

ParallelLogger::saveSettingsToJson(
  object = executionSettings,
  fileName = file.path(resultsFolder, "executionSettings.json")
)

Strategus::execute(
  analysisSpecifications = analysisSpecifications,
  executionSettings = executionSettings,
  connectionDetails = connectionDetails
)
