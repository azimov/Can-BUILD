################################################################################
# Create the Strategus analysis specification
#
# WHAT THIS STUDY DOES
# --------------------
# The primary output is INCIDENCE RATES: how often each outcome of interest
# occurs per 100 person-years, by calendar year.
#
#   Targets  : PLACEHOLDER cohorts from the OHDSI demo ATLAS (cohort IDs 1 and
#              2), standing in for the real target cohorts until they are
#              defined. The real targets will be one cohort per calendar year:
#              everyone who has a visit on 1 January of that year.
#   Outcomes : PLACEHOLDER cohort from the OHDSI demo ATLAS (cohort ID 3).
#   Modules  : CohortGenerator -> CohortDiagnostics -> Characterization (v4)
#
# Every cohort in this study is an ATLAS cohort: it is downloaded by
# scriptsForStudyDesigner/DownloadAssets.R into inst/ and built by the
# CohortGenerator module. There is no custom SQL in the study.
#
# REQUIREMENTS
# ------------
# R 4.6.2 and the package versions pinned in renv.lock. In particular this
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
# inst/Cohorts.csv lists the cohorts and where they came from in ATLAS. The
# files it points at (inst/cohorts/*.json, inst/sql/sql_server/*.sql) are
# written by scriptsForStudyDesigner/DownloadAssets.R.
cohortDefinitionSet <- CohortGenerator::getCohortDefinitionSet(
  settingsFileName = file.path(config$projectRootFolder, "inst", "Cohorts.csv"),
  jsonFolder = file.path(config$projectRootFolder, "inst", "cohorts"),
  sqlFolder = file.path(config$projectRootFolder, "inst", "sql", "sql_server")
)

# ==============================================================================
# Targets
# ==============================================================================
# PLACEHOLDER TARGETS: two cohorts from the OHDSI demo ATLAS
#   https://atlas-demo.ohdsi.org/atlas/
#   cohort 1 = new users of ACE inhibitors for hypertension
#   cohort 2 = new users of ARBs for hypertension
#
# They exist so the pipeline can be built, tested and demonstrated end to end
# before the real target cohorts are defined. To replace them: define the real
# cohorts in ATLAS, list them in the cohortsToDownload table in
# scriptsForStudyDesigner/DownloadAssets.R, run that script, and point
# targetIds at the new cohort IDs.
targetIds <- c(1, 2)

missingTargets <- setdiff(targetIds, cohortDefinitionSet$cohortId)
if (length(missingTargets) > 0) {
  stop(
    "These target cohort IDs are not in inst/Cohorts.csv: ",
    paste(missingTargets, collapse = ", ")
  )
}

# ==============================================================================
# Outcomes
# ==============================================================================
# PLACEHOLDER OUTCOME: cohort 3 = first observed cough, also from the OHDSI demo
# ATLAS. Replace it the same way as the targets.
#
# cleanWindow is the number of days that must pass between two outcome events
# before the second one counts as a new event.
outcomes <- tibble::tribble(
  ~cohortId, ~cleanWindow,
  3,         99999, # Note that is is only for incidence rate setting not used in prevelant design
  4,         99999
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
# For these cohorts the cohort start date is the index date (the first drug
# exposure) and the cohort end date is the end of the exposure. So a time at
# risk of "day 1 to cohort end" is on-treatment follow-up, which is the
# denominator of the incidence rates.

# Incidence TAR
riskWindowStart <- 1
startAnchor <- "cohort start"
riskWindowEnd <- 365
endAnchor <- "cohort start"

# Prevelance TAR
prevelanceRiskWindowStart <- 0
prevelanceRiskWindowEnd <- 1



# ==============================================================================
# Characterization settings
# ==============================================================================
# Characterization v4 replaces the old collection of flat module arguments with
# a small set of settings objects. A "study population" says which target
# cohorts to include and how to restrict them; each analysis (baseline, risk
# factors, incidence, ...) then takes that study population plus its own
# options

studyPeriods <- list(
  list(startDate = NULL, endDate = NULL),
  list(startDate = "20160401", endDate = "20170331"),
  list(startDate = "20170401", endDate = "20180331"),
  list(startDate = "20180401", endDate = "20190331"),
  list(startDate = "20190401", endDate = "20200331"),
  list(startDate = "20200401", endDate = "20210331"),
  list(startDate = "20210401", endDate = "20220331"),
  list(startDate = "20220401", endDate = "20230331"),
  list(startDate = "20230401", endDate = "20240331"),
  list(startDate = "20240401", endDate = "20250331"),
  list(startDate = "20250401", endDate = "20260331"),
  list(startDate = "20260401", endDate = "20270331")
)

studyPopulationSettings <- lapply(studyPeriods, function(period) {
  Characterization::createStudyPopulationSettings(
    targetIds = c(targetIds, outcomes$cohortId)
    limitToFirstInNDays = 0, # keep every cohort episode
    minPriorObservation = 365, # no prior observation requirement
    minAge = NULL, # no age restriction
    maxAge = NULL, # no age restriction
    studyStartDate = period$startDate,
    studyEndDate = period$startEnd,
    genderConceptIds = NULL # all genders
  )
})

# Baseline covariates. This is the Characterization default set with one
# change: the day-level "time in cohort" feature is off, because it builds one
# row per cohort day per person and is the most expensive covariate by far.
baselineCovariateSettings <- list(
  FeatureExtraction::createCovariateSettings(
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
  ),
  FeatureExtraction::createCohortBasedCovariateSettings(
    analysisId = 2, 
    covariateCohorts = outcomes, # TODO - join to CDS for cohort name
    startDay = -99999,
    endDay = 0
  )
)

characterizationSettings <- Characterization::createCharacterizationSettings(
  # Who is in the denominator: age, sex, conditions, drugs, ...
  targetBaselineSettings = Characterization::createTargetBaselineSettings(
    studyPopulationSettings = studyPopulationSettings,
    covariateSettings = baselineCovariateSettings
  ),
  # THE PRIMARY OUTPUT: events and person time per outcome, by calendar year
  # and stratified by age and gender, as a rate per 100 person-years.
  cohortIncidenceSettings = list(
      Characterization::createCohortIncidenceSettings(
        studyPopulationSettings = studyPopulationSettings,
        outcomeIds = outcomes$cohortId,
        outcomeWashoutDays = outcomes$cleanWindow,
        riskWindowStart = riskWindowStart,
        startAnchor = startAnchor,
        riskWindowEnd = riskWindowEnd,
        endAnchor = endAnchor,
        byYear = TRUE, # report rates per calendar year
        byGender = TRUE,
        byAge = TRUE,
        ageBreaks = seq(0, 110, by = 5)
    ),
    # Point prevelance design
    Characterization::createCohortIncidenceSettings(
        studyPopulationSettings = studyPopulationSettings,
        outcomeIds = outcomes$cohortId,
        outcomeWashoutDays = 0,
        riskWindowStart = prevelanceRiskWindowStart,
        startAnchor = startAnchor,
        riskWindowEnd = prevelanceRiskWindowEnd,
        endAnchor = endAnchor,
        byYear = TRUE, # report rates per calendar year
        byGender = TRUE,
        byAge = TRUE,
        ageBreaks = seq(0, 110, by = 5)
    )
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
  # Temporal cohort characterization builds a large covariate table and is the
  # heaviest part of the module; it is off so the diagnostics fit alongside the
  # other containers on a small machine.
  runTemporalCohortCharacterization = FALSE,
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
  "  targets : ", paste(targetIds, collapse = ", "), " (PLACEHOLDER cohorts)\n",
  "  outcomes: ", paste(outcomes$cohortId, collapse = ", "), " (PLACEHOLDER cohort)"
)
