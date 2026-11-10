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
# Database settings come from config.user.yml (yours, not committed) and the
# password from .Renviron (also not committed):
#
#   config.yml         checked in. Study defaults.
#   config.user.yml    NOT checked in. Your server, schemas, driver folder.
#   .Renviron          NOT checked in. The database password only.
#
# To check your setup, or be walked through creating those files:
#
#   source("DatabaseSetup.R")
#
# Anything you leave out of config.user.yml falls back to config.yml. Every
# value can also be set with an OHDSI_* environment variable, which wins.
source("scriptsForStudyDesigner/getStudyConfig.R")
config <- getStudyConfig()
db <- studyDatabaseSettings(config)

cdmDatabaseSchema <- Sys.getenv("OHDSI_CDM_SCHEMA", db$cdmDatabaseSchema)
workDatabaseSchema <- Sys.getenv("OHDSI_WORK_SCHEMA", db$workDatabaseSchema)
cohortTableName <- Sys.getenv("OHDSI_COHORT_TABLE", db$cohortTableName)
databaseName <- Sys.getenv("OHDSI_DATABASE_NAME", db$databaseName)
minCellCount <- as.integer(Sys.getenv("OHDSI_MIN_CELL_COUNT", db$minCellCount))
resultsFolder <- config$resultFolder # Where the output files will be written
workFolder <- config$workFolder # Where the intermediate work files will be written

# DatabaseConnector 8 needs Java 11+ and the JDBC driver folder passed
# explicitly. JAVA_HOME is read from the environment; DatabaseSetup.R checks it.
if (nzchar(config$javaHome %||% "")) {
  Sys.setenv(JAVA_HOME = config$javaHome)
}
Sys.setenv(DATABASECONNECTOR_JAR_FOLDER = db$pathToDriver %||% "")

# Connection details. The password is read from the environment by
# studyConnectionDetails(), so it never appears in this script or in the YAML.
connectionDetails <- studyConnectionDetails(db, config)

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
