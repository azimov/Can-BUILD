# Design Your Study

These are the steps to design the study and to build the [Strategus](https://github.com/OHDSI/Strategus)
analysis specification that `ExecuteAnalyses.R` runs. They assume you have a
protocol, that your cohorts have been designed and reviewed, and that you have
approval to execute the study.

## Study design in one page

| | |
|---|---|
| Targets | Fiscal year cohorts 1 and 2: observation on 1 April, year to 31 March, 365 vs 1095 days prior observation |
| Outcomes | Cohort 3, a dummy outcome, until the real outcome cohorts are defined in ATLAS |
| Primary output | Incidence rate per 100 person-years by calendar year, plus a point-prevalence design |
| Study periods | 12: one unrestricted, plus 11 fiscal years from 2016/17 |
| Modules | CohortGenerator, CohortDiagnostics, Characterization (v4) |

There is no estimation (CohortMethod, SelfControlledCaseSeries) and no
prediction (PatientLevelPrediction) in this study.

## Download study assets

`DownloadAssets.R` downloads cohort definitions from ATLAS into `inst/`
(`Cohorts.csv`, `inst/cohorts/*.json`, `inst/sql/sql_server/*.sql`).

Every cohort in the study comes from ATLAS, so this script is the only way
cohorts get into the repository. There is no hand-written cohort SQL.

To use it:

1. Set `webApiUrl` to your ATLAS instance. It is read from config.yml, or from
   config.user.yml if you have one.
2. List the cohorts you want in the `cohortsToDownload` table in
   `DownloadAssets.R` (ATLAS cohort ID, local cohort ID, cohort name).
3. Run the script from the project root.

## Create the analysis specification

`CreateStrategusAnalysisSpecifications.R` builds the Strategus analysis
specification and writes it to `inst/analysisSpecifications.json`. Run it from
the project root:

```r
source("scriptsForStudyDesigner/CreateStrategusAnalysisSpecifications.R")
```

It contains three things you edit.

### 1. Targets

```r
targetIds <- 2015:2024
```

The cohort IDs of the target cohorts (the two fiscal-year cohorts).

### 2. Outcomes

```r
outcomes <- tibble::tribble(
  ~cohortId, ~cleanWindow,
  3,         99999
)
```

`cohortId` is the outcome cohort ID. `cleanWindow` is the number of days that
must pass between two events before the second one counts as a new event.

The large `cleanWindow` makes the incidence design see at most one event per
person; the point-prevalence design passes its own washout of 0. **Cohort 3 is a
dummy outcome** until the real outcome cohorts are defined in ATLAS. Replace the
IDs (and the rows in `inst/Cohorts.csv`) when they are.

### 3. Time at risk

```r
riskWindowStart <- 1
startAnchor <- "cohort start"
riskWindowEnd <- 0
endAnchor <- "cohort end"
```

These are observation cohorts, not drug exposures: each cohort starts on
1 April and ends the following 31 March. The incidence design follows people for
one year from the cohort start; the point-prevalence design measures on the index
date. See `Time at risk` in `CreateStrategusAnalysisSpecifications.R`.

## How the settings fit together (Characterization v4)

Characterization v4 no longer takes a long list of module arguments. You build a
few settings objects instead:

- `createStudyPopulationSettings()` says which target cohorts to use and how to
  restrict them (prior observation, age, gender, study dates). This study uses
  no restrictions.
- `createTargetBaselineSettings()` produces the baseline characteristics of each
  target cohort.
- `createCohortIncidenceSettings()` produces the incidence rates, with
  `byAge`, `byGender` and `ageBreaks` controlling the strata.
- `createCharacterizationSettings()` collects the analyses.

The Strategus `CharacterizationModule` then takes that object:

```r
CharacterizationModule$new()$createModuleSpecifications(
  characterizationSettings = characterizationSettings,
  ...
)
```

This requires Strategus >= 1.6.0 (the Characterization module moved into
Strategus in 1.6.0) and Characterization >= 4.0.0.

## Choose Strategus modules

The specification in this repository contains:

- **CohortGeneratorModule** - builds all the cohorts.
- **CohortDiagnosticsModule** - cohort diagnostics for the cohorts.
- **CharacterizationModule** - baseline characteristics and incidence rates.

Remove a module from `moduleSpecsList` at the bottom of
`CreateStrategusAnalysisSpecifications.R` if the study does not need it, and
remove its settings block above.

## Test the study

Before distributing the study repository, run it end to end against a test
database. On this machine the local OHDSI Lab is already configured in
`ExecuteAnalyses.R`; see the repository README for the `cdm_vocab` view layer
the lab needs.

Check that:

- `renv::restore()` completes.
- The analysis specification is regenerated after the last design change.
- `ExecuteAnalyses.R` runs all three modules without errors.
- `results/<databaseName>/` contains the Characterization CSVs, in particular
  `c_incidence_summary.csv`, and that the rates look plausible.
- `ShareResults.R` can zip the results.
