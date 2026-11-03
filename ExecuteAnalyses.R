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
# These values point at the local OHDSI Lab on this machine. Change them for
# any other database.
#
#   cdm_vocab is a view layer over the lab's clinical schema (cdm) and its
#   vocabulary schema (vocab). The lab keeps the two apart; this study, like
#   every other HADES analysis, needs them in a single schema. If your site has
#   a normal OMOP CDM with the vocabulary tables in it, just use that schema
#   name here (e.g. "cdm").
cdmDatabaseSchema <- "cdm_vocab"
workDatabaseSchema <- "can_build" # Where the study tables are written
cohortTableName <- "can_build_cohort" # Where the cohorts will be written
resultsFolder <- "results" # Where the output files will be written
workFolder <- "strategusInternals" # Where the intermediate work files will be written
databaseName <- "SYNTHEA10K" # Only used as a folder name for results from the study
minCellCount <- 5 # Minimum cell count for inclusion in output tables

# Create the connection details for your CDM. The defaults below are the local
# OHDSI Lab credentials; the environment variables let you point the same script
# at another machine without editing it.
# More details: https://ohdsi.github.io/DatabaseConnector/reference/createConnectionDetails.html
#
# DatabaseConnector needs a JDBC driver to talk to the database. Set
# DATABASECONNECTOR_JAR_FOLDER to the folder holding it (the lab keeps it in
# ohdsi-lab/analysis/.jdbc), or download it once with
# DatabaseConnector::downloadJdbcDrivers("postgresql").
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = Sys.getenv("OHDSI_DBMS", "postgresql"),
  server = Sys.getenv("OHDSI_SERVER", "127.0.0.1/postgres"),
  port = as.integer(Sys.getenv("OHDSI_PORT", "5432")),
  user = Sys.getenv("OHDSI_USER", "postgres"),
  password = Sys.getenv("OHDSI_PASSWORD", "mypass"),
  pathToDriver = Sys.getenv("DATABASECONNECTOR_JAR_FOLDER")
)

# You can use this snippet to test your connection
#conn <- DatabaseConnector::connect(connectionDetails)
#DatabaseConnector::disconnect(conn)

##=========== END OF INPUTS ==========

##################################
# DO NOT MODIFY BELOW THIS POINT
##################################
config <- config::get()

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

# Build the calendar-year target cohorts -------------------
# These cohorts are SQL, not Circe/ATLAS cohort definitions (see
# scriptsForStudyDesigner/BuildCalendarYearCohorts.R), so Strategus cannot build
# them as part of the run. They are created first, in the same cohort table the
# Strategus modules read, and the CohortGenerator module then adds the outcome
# cohorts on top.
source("scriptsForStudyDesigner/BuildCalendarYearCohorts.R")

buildCalendarYearCohorts(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortDatabaseSchema = workDatabaseSchema,
  cohortTableNames = cohortTableNames
)

Strategus::execute(
  analysisSpecifications = analysisSpecifications,
  executionSettings = executionSettings,
  connectionDetails = connectionDetails
)
