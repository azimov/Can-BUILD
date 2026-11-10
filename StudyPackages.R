################################################################################
# Study package manifest
#
# WHY THIS FILE EXISTS
# ------------------------------------------------------------------------------
# renv.lock is the HADES-wide lock file: it pins ~286 packages, including
# CohortDiagnostics, the results Shiny app and the report generator. Most of
# those are never named in a library() call by the study scripts, because they
# are loaded indirectly - Strategus loads its modules at run time, and the
# Shiny app is a separate entry point.
#
# renv::snapshot() records only what it can SEE the code using. Pointed at this
# repository it finds very few packages and writes a lock file containing almost
# nothing - silently dropping CohortDiagnostics, OhdsiShinyAppBuilder,
# OhdsiShinyModules, OhdsiReportGenerator and the rest.
#
# renv finds dependencies by scanning for library(pkg) and pkg::fun. Every
# package listed below is therefore one we want to KEEP PINNED, and listing it
# here is what makes renv::snapshot() safe.
#
# HOW TO USE IT
# ------------------------------------------------------------------------------
#   renv::restore()    # install exactly what renv.lock pins
#   renv::snapshot()   # now safe: everything below survives
#
# Adding a package:
#   1. renv::install("<pkg>")
#   2. Add library(<pkg>) below, with a comment saying why it is needed.
#   3. renv::snapshot()
#
# IS IT SAFE TO SOURCE THIS FILE?
# ------------------------------------------------------------------------------
# Sourcing it only ATTACHES packages; it does not query a database, touch
# patient data, or make network calls. You do not need to source it for renv to
# see it - renv reads the file statically, without running it.
#
# If you do not want to attach all of these, read the file, or ignore it: the
# study scripts never source it.
################################################################################

# ------------------------------------------------------------------------------
# Strategus: runs the study
# ------------------------------------------------------------------------------
library(Strategus)

# ------------------------------------------------------------------------------
# HADES modules used by ExecuteAnalyses.R
# ------------------------------------------------------------------------------
library(CohortGenerator)       # builds the cohorts
library(CohortDiagnostics)     # cohort diagnostics (loaded by Strategus at run time)
library(Characterization)      # baseline characteristics, incidence, prevalence
library(CohortIncidence)       # incidence calculations behind Characterization
library(FeatureExtraction)     # covariates

# ------------------------------------------------------------------------------
# HADES infrastructure
# ------------------------------------------------------------------------------
library(DatabaseConnector)     # database connections
library(SqlRender)             # SQL dialect translation
library(ParallelLogger)        # logging and parallel execution
library(ResultModelManager)    # writes results into the results database
library(Andromeda)             # storage for large data objects
library(CirceR)                # builds cohort SQL from ATLAS definitions

# ------------------------------------------------------------------------------
# Results sharing, app and reporting
# Not used by ExecuteAnalyses.R. Needed afterwards - which is exactly why they
# must stay pinned.
# ------------------------------------------------------------------------------
library(shiny)                 # the results app; OhdsiShinyAppBuilder depends on it
library(OhdsiShinyAppBuilder)  # builds the results Shiny app
library(OhdsiShinyModules)     # module content shown in that app
library(OhdsiReportGenerator)  # generates reports from results
library(OhdsiSharing)          # SFTP upload/download used by ShareResults.R

# ------------------------------------------------------------------------------
# Study design scripts (scriptsForStudyDesigner/)
# ------------------------------------------------------------------------------
library(ROhdsiWebApi)          # DownloadAssets.R downloads cohorts from ATLAS
library(Capr)                  # cohort definition helpers used with ROhdsiWebApi

# ------------------------------------------------------------------------------
# Estimation and prediction
# This study (incidence and prevalence) does not run these, but the study pack
# is shared with other Can-BUILD analyses and the lock file pins them.
# ------------------------------------------------------------------------------
library(CohortMethod)
library(SelfControlledCaseSeries)
library(PatientLevelPrediction)
library(EvidenceSynthesis)
library(TreatmentPatterns)
library(CohortExplorer)
library(PheValuator)
library(SelfControlledCohort)

# ------------------------------------------------------------------------------
# Everyday R packages used by the scripts
# ------------------------------------------------------------------------------
library(dplyr)                 # data manipulation in the analysis specification
library(tibble)                # the outcomes tribble
library(readr)                 # reading CSV results
library(data.table)            # used in cohort assembly
library(jsonlite)              # reading and writing analysis specifications
library(config)                # config.yml
library(yaml)                  # config.local.yml
library(keyring)               # optional: store the database password
library(getPass)               # hidden password prompt in SetupDatabaseSettings.R
library(cli)                   # progress messages
library(checkmate)             # input validation in HADES packages
library(rlang)                 # error messages

# ------------------------------------------------------------------------------
# Environment management
# ------------------------------------------------------------------------------
library(renv)
