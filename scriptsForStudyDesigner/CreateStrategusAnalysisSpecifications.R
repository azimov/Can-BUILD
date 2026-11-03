################################################################################
# Create the Strategus analysis specification
#
# WHAT THIS STUDY DOES
# --------------------
# The primary output is INCIDENCE RATES: how often each outcome of interest
# occurs per 100 person-years, in each calendar year.
#
#   Targets  : one cohort per calendar year (2015-2024). Everyone who is under
#              observation at some point in that year, with person time running
#              from their first observed day in the year to their last.
#   Outcomes : two PLACEHOLDER outcome cohorts (see "Outcomes" below). The real
#              outcome cohorts have not been defined in ATLAS yet.
#   Modules  : CohortGenerator -> CohortDiagnostics -> Characterization (v4)
#
# REQUIREMENTS
# ------------
# R 4.6.1 and the package versions pinned in renv.lock. In particular this
# script uses the Characterization v4 settings API, which requires
# Strategus >= 1.6.0 (the CharacterizationModule now lives in Strategus) and
# Characterization >= 4.0.0.
#
# You only need to run this script once, after changing the study design:
# it writes inst/analysisSpecifications.json, which is what ExecuteAnalyses.R
# reads.
################################################################################
library(Strategus)
library(tibble)
config <- config::get()

# ==============================================================================
# Cohort assets
# ==============================================================================
# inst/Cohorts.csv lists the cohorts that come from ATLAS - here, the outcome
# cohorts. The calendar-year target cohorts are not ATLAS cohorts: they are
# plain SQL in inst/sql/calendar_year/<year>.sql and are built by
# BuildCalendarYearCohorts.R.
cohortDefinitionSet <- CohortGenerator::getCohortDefinitionSet(
  settingsFileName = file.path(config$projectRootFolder, "inst", "Cohorts.csv"),
  jsonFolder = file.path(config$projectRootFolder, "inst", "cohorts"),
  sqlFolder = file.path(config$projectRootFolder, "inst", "sql", "sql_server")
)

# ==============================================================================
# Targets: the calendar-year cohorts
# ==============================================================================
# The cohort ID of a year cohort is the year itself, and there is one SQL file
# per year. Add a year by adding targetYears and inst/sql/calendar_year/<year>.sql.
targetYears <- 2015:2024
targetIds <- targetYears

yearSqlFiles <- list.files(
  file.path(config$projectRootFolder, "inst", "sql", "calendar_year"),
  pattern = "\\.sql$"
)
missingTargets <- setdiff(paste0(targetIds, ".sql"), yearSqlFiles)
if (length(missingTargets) > 0) {
  stop(
    "No calendar-year cohort SQL found for: ",
    paste(sub("\\.sql$", "", missingTargets), collapse = ", "),
    " (expected in inst/sql/calendar_year/)"
  )
}

# ==============================================================================
# Outcomes
# ==============================================================================
# PLACEHOLDER OUTCOMES. The study outcome cohorts are not defined in ATLAS yet.
# Cohorts 101 and 102 are stand-ins so that the pipeline can be built, tested
# and demonstrated end to end. They are ordinary diabetes/hypertension
# condition cohorts, clearly named PLACEHOLDER in the cohort set.
#
# To swap in the real outcome cohorts:
#   1. define them in ATLAS,
#   2. add them to the cohortsToDownload tribble in
#      scriptsForStudyDesigner/DownloadAssets.R and run it,
#   3. replace the cohort IDs below (and the rows in inst/Cohorts.csv),
#   4. re-run this script.
#
# cleanWindow is the number of days that must pass between two outcome events
# before the second one counts as a new event.
outcomes <- tibble::tribble(
  ~cohortId, ~cleanWindow,
  101,       365,          # PLACEHOLDER outcome 1 - type 2 diabetes
  102,       365           # PLACEHOLDER outcome 2 - essential hypertension
)

missingOutcomes <- setdiff(outcomes$cohortId, cohortDefinitionSet$cohortId)
if (length(missingOutcomes) > 0) {
  stop(
    "These outcome cohort IDs are not in inst/Cohorts.csv: ",
    paste(missingOutcomes, collapse = ", ")
  )
}

# ==============================================================================
# Time at risk
# ==============================================================================
# For a calendar-year cohort the cohort start date is the first day the person
# was observed in the year and the cohort end date is the last day. So a time
# at risk of "day 1 to cohort end" is simply "the rest of the time we can see
# them this year", which is exactly the denominator we want for incidence rates.
riskWindowStart <- 1
startAnchor <- "cohort start"
riskWindowEnd <- 0
endAnchor <- "cohort end"

# ==============================================================================
# Characterization settings
# ==============================================================================
# Characterization v4 replaces the old collection of flat module arguments with
# a small set of settings objects. A "study population" says which target
# cohorts to include and how to restrict them; each analysis (baseline, risk
# factors, incidence, ...) then takes that study population plus its own
# options.
studyPopulationSettings <- Characterization::createStudyPopulationSettings(
  targetIds = targetIds,
  limitToFirstInNDays = 0, # keep every period of observation in the year
  minPriorObservation = 0, # no prior observation requirement
  minAge = NULL, # no age restriction
  maxAge = NULL, # no age restriction
  studyStartDate = NULL, # no calendar restriction beyond the year cohort itself
  studyEndDate = NULL,
  genderConceptIds = NULL # all genders
)

# Baseline covariates. This is the Characterization default set with one
# change: the day-level "time in cohort" feature is off. It builds one row per
# cohort day per person (~25 million rows for ten year cohorts) and adds nothing
# here, because every year cohort is about a year long.
baselineCovariateSettings <- FeatureExtraction::createCovariateSettings(
  useDemographicsGender = TRUE,
  useDemographicsAge = TRUE,
  useDemographicsAgeGroup = TRUE,
  useDemographicsRace = TRUE,
  useDemographicsEthnicity = TRUE,
  useDemographicsIndexYear = TRUE,
  useDemographicsIndexMonth = TRUE,
  useDemographicsPriorObservationTime = TRUE,
  useDemographicsPostObservationTime = TRUE,
  useConditionGroupEraLongTerm = TRUE,
  useConditionGroupEraShortTerm = TRUE,
  useDrugGroupEraLongTerm = TRUE,
  useDrugGroupEraShortTerm = TRUE,
  useDrugGroupEraOverlapping = TRUE,
  useProcedureOccurrenceLongTerm = TRUE,
  useProcedureOccurrenceShortTerm = TRUE,
  useMeasurementLongTerm = TRUE,
  useMeasurementShortTerm = TRUE,
  useObservationLongTerm = TRUE,
  useObservationShortTerm = TRUE,
  useDeviceExposureLongTerm = TRUE,
  useDeviceExposureShortTerm = TRUE,
  useVisitConceptCountLongTerm = TRUE,
  useVisitConceptCountShortTerm = TRUE,
  useCharlsonIndex = TRUE,
  endDays = 0,
  longTermStartDays = -365,
  shortTermStartDays = -30
)

characterizationSettings <- Characterization::createCharacterizationSettings(
  # Who is in each year's denominator: age, sex, conditions, drugs, ...
  targetBaselineSettings = Characterization::createTargetBaselineSettings(
    studyPopulationSettings = studyPopulationSettings,
    covariateSettings = baselineCovariateSettings
  ),
  # THE PRIMARY OUTPUT: events and person time per year, per outcome,
  # stratified by age and gender, reported as a rate per 100 person-years.
  cohortIncidenceSettings = Characterization::createCohortIncidenceSettings(
    studyPopulationSettings = studyPopulationSettings,
    outcomeIds = outcomes$cohortId,
    outcomeWashoutDays = outcomes$cleanWindow,
    riskWindowStart = riskWindowStart,
    startAnchor = startAnchor,
    riskWindowEnd = riskWindowEnd,
    endAnchor = endAnchor,
    byYear = FALSE, # the target cohort already is the calendar year
    byGender = TRUE,
    byAge = TRUE,
    ageBreaks = seq(0, 110, by = 10)
  )
)

# ==============================================================================
# Strategus modules
# ==============================================================================
# Only the descriptive modules are used. There is no PLE/PLP and no
# CohortMethod / SelfControlledCaseSeries in this study, so those module
# specifications are simply not created.

## CohortGenerator: build the outcome cohorts -------------------------------
# Only the outcome cohorts are in the shared resource: Strategus rebuilds every
# cohort in it from its Circe JSON when it runs, and the calendar-year cohorts
# have no JSON (they are built by BuildCalendarYearCohorts.R, called from
# ExecuteAnalyses.R, before the run).
cgModuleSettingsCreator <- CohortGeneratorModule$new()
cohortDefinitionShared <- cgModuleSettingsCreator$createCohortSharedResourceSpecifications(
  cohortDefinitionSet
)
cohortGeneratorModuleSpecifications <- cgModuleSettingsCreator$createModuleSpecifications(
  generateStats = TRUE
)

## CohortDiagnostics: check the outcome cohorts -----------------------------
# Run on the outcome cohorts only. The calendar-year cohorts are SQL-defined
# and have no concept-level content to diagnose.
cdModuleSettingsCreator <- CohortDiagnosticsModule$new()
cohortDiagnosticsModuleSpecifications <- cdModuleSettingsCreator$createModuleSpecifications(
  cohortIds = outcomes$cohortId,
  runInclusionStatistics = TRUE,
  runIncludedSourceConcepts = TRUE,
  runOrphanConcepts = TRUE,
  runTimeSeries = FALSE,
  runVisitContext = TRUE,
  runBreakdownIndexEvents = TRUE,
  runIncidenceRate = TRUE,
  runCohortRelationship = TRUE,
  runTemporalCohortCharacterization = TRUE,
  minCharacterizationMean = 0.01
)

## Characterization: baseline characteristics and incidence rates -----------
cModuleSettingsCreator <- CharacterizationModule$new()
characterizationModuleSpecifications <- cModuleSettingsCreator$createModuleSpecifications(
  characterizationSettings = characterizationSettings,
  minCharacterizationMean = 0.01,
  minCovariateCount = 5,
  mode = "CohortIncidence",
  outputTable = "characterization_cohorts"
)

# ==============================================================================
# Assemble the analysis specification
# ==============================================================================
# To disable a module, remove it from this list.
moduleSpecsList <- list(
  cohortGeneratorModuleSpecifications,
  cohortDiagnosticsModuleSpecifications,
  characterizationModuleSpecifications
)

sharedResourcesList <- list(cohortDefinitionShared)

analysisSpecifications <- Strategus::createEmptyAnalysisSpecifications()
for (sharedResource in sharedResourcesList) {
  analysisSpecifications <- Strategus::addSharedResources(analysisSpecifications, sharedResource)
}
for (moduleSpec in moduleSpecsList) {
  analysisSpecifications <- Strategus::addModuleSpecifications(analysisSpecifications, moduleSpec)
}

specificationFileName <- file.path(
  config$projectRootFolder,
  "inst",
  config$studySpecificationFileName
)
ParallelLogger::saveSettingsToJson(analysisSpecifications, specificationFileName)

message(
  "Analysis specification written to ", specificationFileName, "\n",
  "  targets : calendar years ", min(targetIds), "-", max(targetIds),
  " (", length(targetIds), " cohorts)\n",
  "  outcomes: ", paste(outcomes$cohortId, collapse = ", "),
  " (PLACEHOLDER cohorts)"
)
