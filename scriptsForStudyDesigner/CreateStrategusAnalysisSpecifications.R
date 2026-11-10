################################################################################
# Create the Strategus analysis specification
#
# WHAT THIS STUDY DOES
# --------------------
# The primary output is INCIDENCE RATES: how often each outcome of interest
# occurs per 100 person-years, by calendar year. A point-prevalence analysis
# runs alongside it.
#
#   Targets  : cohort 1 = fiscal year cohort, 365 days prior observation
#              cohort 2 = fiscal year cohort, 1095 days prior observation
#              Anyone with observation on 1 April of each calendar year, with
#              the fiscal year running to the following 31 March.
#   Outcomes : cohort 3 = angioedema/urticaria (ATLAS id 1797622, a dummy)
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
# The two fiscal-year observation cohorts. Anyone with observation on 1 April
# of each calendar year, with the fiscal year running to the following 31 March.
# They differ only in how much prior observation they require (365 vs 1095 days).
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
# Cohort 3 is a dummy outcome (ATLAS id 1797622). The large cleanWindow is there
# so that the incidence design sees, at most, one event per person; it is not
# used by the point-prevalence design below, which passes its own washout.
#
# cleanWindow is the number of days that must pass between two outcome events
# before the second one counts as a new event.
outcomes <- tibble::tribble(
  ~cohortId, ~cleanWindow,
  3,         99999 # Note that this is only for the incidence rate setting, not used in prevalent design
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
# These are observation cohorts, not drug exposures: the cohort start date is
# the fiscal year start and the cohort end date is the end of that fiscal year.

# Incidence TAR: one year of follow-up from the cohort start.
riskWindowStart <- 1
startAnchor <- "cohort start"
riskWindowEnd <- 365
endAnchor <- "cohort start"

# Prevalence TAR: point prevalence on the index date.
prevalenceRiskWindowStart <- 0
prevalenceRiskWindowEnd <- 1

# ==============================================================================
# Characterization settings
# ==============================================================================
# Characterization v4 replaces the old collection of flat module arguments with
# a small set of settings objects. A "study population" says which target
# cohorts to include and how to restrict them; each analysis (baseline, risk
# factors, incidence, ...) then takes that study population plus its own
# options.
#
# One study population per study period: the first has no date restriction, the
# rest are successive fiscal years. Each study population is paired with the
# same baseline-covariate and incidence settings below.
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
    targetIds = c(targetIds, outcomes$cohortId),
    limitToFirstInNDays = 0, # keep every cohort episode
    minPriorObservation = 365, # one year of prior observation
    minAge = NULL, # no age restriction
    maxAge = NULL, # no age restriction
    studyStartDate = period$startDate,
    studyEndDate = period$endDate,
    genderConceptIds = NULL # all genders
  )
})

# Baseline covariates. This is the Characterization default set with one
# change: the day-level "time in cohort" feature is off, because it builds one
# row per cohort day per person and is the most expensive covariate by far.
#
# The second entry adds the outcome cohort as a cohort-based covariate, so that
# "had the outcome at any point before the index date" is captured for each
# target.
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
    # FeatureExtraction prespecifies analysis IDs 1-926 and requires <= 999,
    # so use an ID in the free 927-999 window.
    analysisId = 950,
    # createCohortBasedCovariateSettings needs cohortId and cohortName, so join
    # the outcome IDs back to the cohort definition set.
    covariateCohorts = cohortDefinitionSet |>
      dplyr::filter(cohortId %in% outcomes$cohortId) |>
      dplyr::select(cohortId, cohortName) |>
      dplyr::collect(),
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
  # THE PRIMARY OUTPUT: events and person time by calendar year and stratified
  # by age and gender, as a rate per 100 person-years, plus a point-prevalence
  # design alongside it.
  cohortIncidenceSettings = list(
    # Incidence rate design
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
    # Point prevalence design
    Characterization::createCohortIncidenceSettings(
      studyPopulationSettings = studyPopulationSettings,
      outcomeIds = outcomes$cohortId,
      outcomeWashoutDays = 0,
      riskWindowStart = prevalenceRiskWindowStart,
      startAnchor = startAnchor,
      riskWindowEnd = prevalenceRiskWindowEnd,
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

## CohortGenerator: build the cohorts ---------------------------------------
cgModuleSettingsCreator <- CohortGeneratorModule$new()
cohortDefinitionShared <- cgModuleSettingsCreator$createCohortSharedResourceSpecifications(
  cohortDefinitionSet
)
cohortGeneratorModuleSpecifications <- cgModuleSettingsCreator$createModuleSpecifications(
  generateStats = TRUE
)

## CohortDiagnostics: check the cohorts --------------------------------------
cdModuleSettingsCreator <- CohortDiagnosticsModule$new()
cohortDiagnosticsModuleSpecifications <- cdModuleSettingsCreator$createModuleSpecifications(
  cohortIds = cohortDefinitionSet$cohortId,
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
  "  targets      : ", paste(targetIds, collapse = ", "), "\n",
  "  outcomes     : ", paste(outcomes$cohortId, collapse = ", "), "\n",
  "  study periods: ", length(studyPeriods), " (", length(studyPopulationSettings), " study populations)"
)
