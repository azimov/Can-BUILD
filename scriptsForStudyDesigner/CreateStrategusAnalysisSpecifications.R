################################################################################
# INSTRUCTIONS: Make sure you have downloaded your cohorts and concept sets 
# using DownloadAssets.R and that those are stored in the "inst" folder of the
# of the project. 
# 
# More information about Strategus HADES modules can be found at:
# https://ohdsi.github.io/Strategus/reference/index.html#omop-cdm-hades-modules.
# This help page also contains links to the corresponding HADES package that
# further details.
# ##############################################################################
library(Strategus)
library(tibble)
config <- config::get()

negativeControlOutcomeCohortSet <- CohortGenerator::readCsv(
  file = file.path(config$projectRootFolder, "inst", "negativeControlOutcomes.csv")
)

covariateConceptsToExclude <- CohortGenerator::readCsv(
  file = file.path(config$projectRootFolder, "inst", "covariateConceptsToExclude.csv")
) |>
  dplyr::pull("conceptId")

cohortDefinitionSet <- CohortGenerator::getCohortDefinitionSet(
  settingsFileName = file.path(config$projectRootFolder, "inst", "Cohorts.csv"),
  jsonFolder = file.path(config$projectRootFolder, "inst", "cohorts"),
  sqlFolder = file.path(config$projectRootFolder, "inst", "sql", "sql_server")
)

tcis <- list(
  #standard analyses that would be performed during routine signal detection
  list(
    targetId = 11, # Celecoxib
    comparatorId = 21, # diclofenac
    indicationId = NULL, # When desired, you can use this to subset the target & comparator to an indication cohort that overlaps the target/comparator start date. Can be NULL.
    genderConceptIds = c(8507, 8532), # use valid genders (remove unknown)
    minAge = NULL, # All ages In years. Can be NULL
    maxAge = NULL, # All ages In years. Can be NULL
    excludedCovariateConceptIds = c(
      1118084, # celecoxib
      1124300  # diclofenac
    ) 
  )
)

outcomes <- tibble::tribble(
  ~cohortId, ~cleanWindow,
  31,    365,          # GI Bleed
)

# Time-at-risks (TARs) for the outcomes of interest in your study
timeAtRisks <- tibble::tribble(
  ~label,         ~riskWindowStart, ~startAnchor,   ~riskWindowEnd, ~endAnchor,
  "On treatment", 1,                "cohort start", 0,              "cohort end"
)
# Try to avoid intent-to-treat TARs for SCCS, or then at least disable calendar time spline:
sccsTimeAtRisks <- tibble::tribble(
  ~label,         ~riskWindowStart, ~startAnchor,   ~riskWindowEnd, ~endAnchor,
  "On treatment", 1,                "cohort start", 0,              "cohort end"
)
# Try to use fixed-time TARs for patient-level prediction:
plpTimeAtRisks <- tibble::tribble(
  ~riskWindowStart, ~startAnchor,   ~riskWindowEnd, ~endAnchor,
  1,                "cohort start", 365,            "cohort start"
)

# If you are not restricting your study to a specific time window, 
# please make these strings empty
studyStartDate <- "" # Specify in "YYYYMMDD" format
studyEndDate <- ""   # Specify in "YYYYMMDD" format

# Probably don't change below this line ----------------------------------------
## Consider these settings for estimation  -------------------------------------
useCleanWindowForPriorOutcomeLookback <- FALSE # If FALSE, lookback window is all time prior, i.e., including only first events
psMatchMaxRatio <- 1 # If bigger than 1, the outcome model will be conditioned on the matched set
cmMaxCohortSizeForFitting <- 250000 # Downsampled example study to 10000
cmMaxCovBalanceCohortSize <- cmMaxCohortSizeForFitting # Used for covariate balance
sccsMaxCasesPerOutcome <- 100000 # Mostly used to limit computation for negative controls. 

## Consider these settings for patient-level prediction  -----------------------
plpMaxSampleSize <- 1000000 # Downsampled example study to 20000

########################################################
# Below the line - DO NOT MODIFY -----------------------
########################################################

# Don't change below this line (unless you know what you're doing) -------------

# Get unique Tcis combinations -------------------------------------------------
dfUniqueTcis <- data.frame()
for (i in seq_along(tcis)) {
  dfUniqueTcis <- rbind(dfUniqueTcis, data.frame(cohortId = tcis[[i]]$targetId,
                                                 indicationId = paste(tcis[[i]]$indicationId, collapse = ","),
                                                 genderConceptIds = paste(tcis[[i]]$genderConceptIds, collapse = ","),
                                                 minAge = paste(tcis[[i]]$minAge, collapse = ","),
                                                 maxAge = paste(tcis[[i]]$maxAge, collapse = ",")
  ))
  if (!is.null(tcis[[i]]$comparatorId)) {
    dfUniqueTcis <- rbind(dfUniqueTcis, data.frame(cohortId = tcis[[i]]$comparatorId,
                                                   indicationId = paste(tcis[[i]]$indicationId, collapse = ","),
                                                   genderConceptIds = paste(tcis[[i]]$genderConceptIds, collapse = ","),
                                                   minAge = paste(tcis[[i]]$minAge, collapse = ","),
                                                   maxAge = paste(tcis[[i]]$maxAge, collapse = ",")
    ))
  }
}

dfUniqueTcis <- unique(dfUniqueTcis)
dfUniqueTcis$subsetDefinitionId <- 0 # Add a column for use when performing subsets

# Create subsets ------------------
dfUniqueSubsetCriteria <- unique(dfUniqueTcis[,-1])

for (i in seq_len(nrow(dfUniqueSubsetCriteria))) {
  uniqueSubsetCriteria <- dfUniqueSubsetCriteria[i,]
  dfCurrentTcis <- dfUniqueTcis[dfUniqueTcis$indicationId == uniqueSubsetCriteria$indicationId &
                                  dfUniqueTcis$genderConceptIds == uniqueSubsetCriteria$genderConceptIds &
                                  dfUniqueTcis$minAge == uniqueSubsetCriteria$minAge & 
                                  dfUniqueTcis$maxAge == uniqueSubsetCriteria$maxAge,]
  targetCohortIdsForSubsetCriteria <- as.integer(dfCurrentTcis[, "cohortId"])
  dfUniqueTcis[dfUniqueTcis$indicationId == dfCurrentTcis$indicationId &
                 dfUniqueTcis$genderConceptIds == dfCurrentTcis$genderConceptIds &
                 dfUniqueTcis$minAge == dfCurrentTcis$minAge & 
                 dfUniqueTcis$maxAge == dfCurrentTcis$maxAge,]$subsetDefinitionId <- i
  
  subsetOperators <- list()
  
  # Always first restrict for CM/PLP - also if running annual IRs need to change limitTo = 'firstEver' to 'all'
  subsetOperators[[length(subsetOperators) + 1]] <- CohortGenerator::createLimitSubsetOperator(
    priorTime = 365,
    followUpTime = 1,
    limitTo = "firstEver"
  )
  
  # Indication restriction (always first if there is an indication)
  indicationName <- ""
  if (uniqueSubsetCriteria$indicationId != "") {
    subsetOperators[[length(subsetOperators) + 1]] <- CohortGenerator::createCohortSubsetOperator(
      cohortIds = uniqueSubsetCriteria$indicationId,
      negate = FALSE,
      cohortCombinationOperator = "all",
      windows = list(
        CohortGenerator::createSubsetCohortWindow(
          startDay = -99999, 
          endDay = 0, 
          targetAnchor = "cohortStart",
          subsetAnchor = "cohortStart"
        ),
        CohortGenerator::createSubsetCohortWindow(
          startDay = 0, 
          endDay = 99999, 
          targetAnchor = "cohortStart",
          subsetAnchor = "cohortEnd"
        )
      )
    )
    # saving name for the cohort subset name
    indicationName <- cohortDefinitionSet$cohortName[cohortDefinitionSet$cohortId == uniqueSubsetCriteria$indicationId]
  }
  
  # Demo settings
  demoName <- ""
  if (uniqueSubsetCriteria$genderConceptIds != "" ||
      uniqueSubsetCriteria$minAge != "" ||
      uniqueSubsetCriteria$maxAge != "") {
    subsetOperators[[length(subsetOperators) + 1]] <- CohortGenerator::createDemographicSubsetOperator(
      ageMin = if(uniqueSubsetCriteria$minAge == "") 0 else as.integer(uniqueSubsetCriteria$minAge),
      ageMax = if(uniqueSubsetCriteria$maxAge == "") 99999 else as.integer(uniqueSubsetCriteria$maxAge),
      gender = if(uniqueSubsetCriteria$genderConceptIds == "") NULL else as.integer(strsplit(uniqueSubsetCriteria$genderConceptIds, ",")[[1]])
    )
    
    if(uniqueSubsetCriteria$genderConceptIds != ""){
      # could map to name but for now doing code to make it generalizable
      demoName <- paste0(" gender ",uniqueSubsetCriteria$genderConceptIds)
    }
    if(uniqueSubsetCriteria$minAge != "" & uniqueSubsetCriteria$maxAge == ""){
      # check the >= is true
      demoName <- paste0(demoName, ' age >= ', uniqueSubsetCriteria$minAge)
    }
    if(uniqueSubsetCriteria$minAge == "" & uniqueSubsetCriteria$maxAge != ""){
      # check the >= is true
      demoName <- paste0(demoName, ' age <= ', uniqueSubsetCriteria$maxAge)
    }
    if(uniqueSubsetCriteria$minAge != "" & uniqueSubsetCriteria$maxAge != ""){
      # check the <= is true
      demoName <- paste0(demoName, ' ', uniqueSubsetCriteria$minAge, ' <= age <= ', uniqueSubsetCriteria$maxAge)
    }
    
  }
  
  # Time settings
  timeName <- ""
  if (studyStartDate != "" || studyEndDate != "") {
    subsetOperators[[length(subsetOperators) + 1]] <- CohortGenerator::createLimitSubsetOperator(
      calendarStartDate = if (studyStartDate == "") NULL else as.Date(studyStartDate, "%Y%m%d"),
      calendarEndDate = if (studyEndDate == "") NULL else as.Date(studyEndDate, "%Y%m%d")
    )
    
    if(studyStartDate != ""){
      timeName <- paste0(" from ", studyStartDate)
    }
    if(studyEndDate != ""){
      timeName <- paste0(timeName, " until ", studyEndDate)
    }
    
  }
  # add the indication/demo/year subset for the targets with this subset
  subsetDef <- CohortGenerator::createCohortSubsetDefinition(
    name = paste0("first time ",ifelse(indicationName == '', '', 'in '), indicationName, demoName, timeName),
    subsetCohortNameTemplate = "@baseCohortName - @subsetDefinitionName",
    definitionId = i,
    subsetOperators = subsetOperators
  )
  cohortDefinitionSet <- cohortDefinitionSet |>
    CohortGenerator::addCohortSubsetDefinition(
      cohortSubsetDefintion = subsetDef,
      targetCohortIds = targetCohortIdsForSubsetCriteria
    ) 
  
  # add the indication cohort without the indication subset
  if (uniqueSubsetCriteria$indicationId != "") {
    # Also create restricted version of indication cohort:
    subsetDef <- CohortGenerator::createCohortSubsetDefinition(
      name = paste0("first time ", demoName, timeName),
      subsetCohortNameTemplate = "@baseCohortName - @subsetDefinitionName",
      definitionId = i + 100,
      subsetOperators = subsetOperators[-2] # indic removed
    )
    cohortDefinitionSet <- cohortDefinitionSet |>
      CohortGenerator::addCohortSubsetDefinition(
        cohortSubsetDefintion = subsetDef,
        targetCohortIds = as.integer(uniqueSubsetCriteria$indicationId)
      )
  }  
}

# Check to make sure there are no duplicated cohort IDs between 
# the cohortDefintionSet and negative control outcome cohorts.
if (!is.null(negativeControlOutcomeCohortSet)) {
  if (length(intersect(cohortDefinitionSet$cohortId, negativeControlOutcomeCohortSet$cohortId)) > 0) {
    dupedCohortIds <- intersect(cohortDefinitionSet$cohortId, negativeControlOutcomeCohortSet$cohortId)
    dupedCohorts <- cohortDefinitionSet |>
      dplyr::filter(cohortId %in% dupedCohortIds) |>
      dplyr::select(cohortId, cohortName) |>
      dplyr::mutate(source = "cohortDefinitionSet")
    dupedNcs <- negativeControlOutcomeCohortSet |>
      dplyr::filter(cohortId %in% dupedCohortIds) |>
      dplyr::select(cohortId, cohortName) |>
      dplyr::mutate(source = "negativeControlOutcomeCohortSet")
    allDupedCohorts <- dupedCohorts |>
      dplyr::bind_rows(dupedNcs)
    cli::cli_alert_danger("Duplicate cohort IDs found in the cohortDefinitionSet and the negativeControlOutcomeCohortSet!")
    print.data.frame(allDupedCohorts)
    stop("*** Please resolve this identifier conflict and try again ***")
  }
}

# Strategus module settings ----------------------------------------------------
## CohortGeneratorModule settings ----------------------------------------------
cgModuleSettingsCreator <- CohortGeneratorModule$new()
cohortDefinitionShared <- cgModuleSettingsCreator$createCohortSharedResourceSpecifications(cohortDefinitionSet)
sharedResourcesList <- list()
sharedResourcesList[[1]] <- cohortDefinitionShared 
if (!is.null(negativeControlOutcomeCohortSet)) {
  negativeControlsShared <- cgModuleSettingsCreator$createNegativeControlOutcomeCohortSharedResourceSpecifications(
    negativeControlOutcomeCohortSet = negativeControlOutcomeCohortSet,
    occurrenceType = "first",
    detectOnDescendants = TRUE
  )
  sharedResourcesList[[length(sharedResourcesList)+1]] <- negativeControlsShared
}
cohortGeneratorModuleSpecifications <- cgModuleSettingsCreator$createModuleSpecifications(
  generateStats = TRUE
)

## CohortDiagnosticsModule settings --------------------------------------------
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
  runTemporalCohortCharacterization = TRUE,
  minCharacterizationMean = 0.01
)

## CharacterizationModule settings ---------------------------------------------
cModuleSettingsCreator <- CharacterizationModule$new()
allCohortIdsExceptOutcomes <- cohortDefinitionSet |>
  dplyr::filter(!cohortId %in% outcomes$cohortId) |>
  dplyr::pull(cohortId)

characterizationModuleSpecifications <- cModuleSettingsCreator$createModuleSpecifications(
  targetIds = allCohortIdsExceptOutcomes,
  outcomeIds = outcomes$cohortId,
  outcomeWashoutDays = outcomes$cleanWindow,
  dechallengeStopInterval = 30,
  dechallengeEvaluationWindow = 30,
  riskWindowStart = timeAtRisks$riskWindowStart,
  startAnchor = timeAtRisks$startAnchor,
  riskWindowEnd = timeAtRisks$riskWindowEnd,
  endAnchor = timeAtRisks$endAnchor,
  minCharacterizationMean = 0.01,
  casePreTargetDuration = 365,
  casePostOutcomeDuration = 365,
  minPriorObservation = 365
)

## CohortIncidenceModule settings --------------------------------------------------------
ciModuleSettingsCreator <- CohortIncidenceModule$new()
exposureIndicationIds <- cohortDefinitionSet |>
  dplyr::filter(!cohortId %in% outcomes$cohortId & isSubset) |>
  dplyr::pull(cohortId)
targetList <- lapply(
  exposureIndicationIds,
  function(cohortId) {
    CohortIncidence::createCohortRef(
      id = cohortId, 
      name = cohortDefinitionSet$cohortName[cohortDefinitionSet$cohortId == cohortId]
    )
  }
)
outcomeList <- lapply(
  seq_len(nrow(outcomes)),
  function(i) {
    CohortIncidence::createOutcomeDef(
      id = i, 
      name = cohortDefinitionSet$cohortName[cohortDefinitionSet$cohortId == outcomes$cohortId[i]], 
      cohortId = outcomes$cohortId[i], 
      cleanWindow = outcomes$cleanWindow[i]
    )
  }
)

tars <- list()
for (i in seq_len(nrow(timeAtRisks))) {
  tars[[i]] <- CohortIncidence::createTimeAtRiskDef(
    id = i, 
    startWith = gsub("cohort ", "", timeAtRisks$startAnchor[i]), 
    endWith = gsub("cohort ", "", timeAtRisks$endAnchor[i]), 
    startOffset = timeAtRisks$riskWindowStart[i],
    endOffset = timeAtRisks$riskWindowEnd[i]
  )
}
analysis1 <- CohortIncidence::createIncidenceAnalysis(
  targets = exposureIndicationIds,
  outcomes = seq_len(nrow(outcomes)),
  tars = seq_along(tars)
)

# NOTE: Passing an empty string to CohortIncidence::createDateRange
# will not work since it assumes a non-missing value is formatted
# as a date string so checking the parameters here so we only pass
# the non-empty values specified by the user
createDateRangeArgs <- list()
studyStartDateWithHyphens <- gsub("(\\d{4})(\\d{2})(\\d{2})", "\\1-\\2-\\3", studyStartDate)
studyEndDateWithHyphens <- gsub("(\\d{4})(\\d{2})(\\d{2})", "\\1-\\2-\\3", studyEndDate)
if (studyStartDateWithHyphens != "") {
  createDateRangeArgs["startDate"] <- studyStartDateWithHyphens
}
if (studyEndDateWithHyphens != "") {
  createDateRangeArgs["endDate"] <- studyEndDateWithHyphens
}
irStudyWindow <- do.call(CohortIncidence::createDateRange, createDateRangeArgs)

irDesign <- CohortIncidence::createIncidenceDesign(
  targetDefs = targetList,
  outcomeDefs = outcomeList,
  tars = tars,
  analysisList = list(analysis1),
  studyWindow = irStudyWindow,
  strataSettings = CohortIncidence::createStrataSettings(
    byYear = TRUE,
    byGender = TRUE,
    byAge = TRUE,
    ageBreaks = seq(0, 110, by = 10)
  )
)
cohortIncidenceModuleSpecifications <- ciModuleSettingsCreator$createModuleSpecifications(
  irDesign = irDesign$toList()
)

# Create the analysis specifications ------------------------------------------
# To disable specific modules, just remove them here:
moduleSpecsList <- list(
  cohortGeneratorModuleSpecifications,
  cohortDiagnosticsModuleSpecifications,
  characterizationModuleSpecifications,
  cohortIncidenceModuleSpecifications
)

analysisSpecifications <- Strategus::createEmptyAnalysisSpecifications()
for (sharedResource in sharedResourcesList) {
  analysisSpecifications <- Strategus::addSharedResources(analysisSpecifications, sharedResource)
}
for (moduleSpec in moduleSpecsList) {
  analysisSpecifications <- Strategus::addModuleSpecifications(analysisSpecifications, moduleSpec)
}

ParallelLogger::saveSettingsToJson(
  analysisSpecifications, 
  file.path(config$projectRootFolder, "inst", config$studySpecificationFileName)
)
