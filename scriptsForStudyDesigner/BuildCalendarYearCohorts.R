################################################################################
# Build the calendar-year target cohorts
#
# "Everyone under observation in a calendar year" cannot be written as an
# ATLAS/Circe cohort definition: Circe has no way to anchor a cohort on the
# observation period, and no way to make a cohort end at the end of the year.
# Those cohorts are therefore plain SQL, one file per year, in
# inst/sql/calendar_year/<year>.sql.
#
# They are kept out of inst/Cohorts.csv (which holds the ATLAS cohorts) so that
# re-running DownloadAssets.R, which rewrites that file, cannot remove them.
#
# Strategus rebuilds every cohort from its Circe JSON when it runs, so these SQL
# cohorts have to be created *before* the Strategus run. This script does that;
# it is sourced and called by ExecuteAnalyses.R and you do not normally run it
# by itself.
#
# The cohorts are written to the same cohort table in the work schema that the
# Strategus modules read, so Characterization sees them like any other cohort.
################################################################################

buildCalendarYearCohorts <- function(connectionDetails,
                                     cdmDatabaseSchema,
                                     cohortDatabaseSchema,
                                     cohortTableNames,
                                     projectRootFolder = config::get()$projectRootFolder) {
  sqlFolder <- file.path(projectRootFolder, "inst", "sql", "calendar_year")
  sqlFiles <- sort(list.files(sqlFolder, pattern = "\\.sql$", full.names = TRUE))
  if (length(sqlFiles) == 0) {
    stop("No calendar-year cohort SQL found in ", sqlFolder)
  }

  cohortIds <- as.integer(sub("\\.sql$", "", basename(sqlFiles)))
  if (any(is.na(cohortIds))) {
    stop("Calendar-year cohort SQL files must be named <year>.sql, e.g. 2015.sql")
  }

  yearCohorts <- data.frame(
    atlasId = NA_integer_,
    cohortId = cohortIds,
    cohortName = paste("Observation year", cohortIds),
    logicDescription = paste("Everyone under observation in calendar year", cohortIds),
    generateStats = TRUE,
    json = NA_character_,
    sql = vapply(sqlFiles, SqlRender::readSql, character(1)),
    stringsAsFactors = FALSE
  )

  ParallelLogger::logInfo(
    "Building ", nrow(yearCohorts), " calendar-year cohorts: ",
    paste(range(yearCohorts$cohortId), collapse = "-")
  )

  # incremental = TRUE: create whatever is missing, never drop a table that is
  # already there (it may already hold the outcome cohorts from a previous run)
  CohortGenerator::createCohortTables(
    connectionDetails = connectionDetails,
    cohortDatabaseSchema = cohortDatabaseSchema,
    cohortTableNames = cohortTableNames,
    incremental = TRUE
  )

  status <- CohortGenerator::generateCohortSet(
    connectionDetails = connectionDetails,
    cdmDatabaseSchema = cdmDatabaseSchema,
    cohortDatabaseSchema = cohortDatabaseSchema,
    cohortTableNames = cohortTableNames,
    cohortDefinitionSet = yearCohorts,
    incremental = TRUE
  )

  return(status)
}
