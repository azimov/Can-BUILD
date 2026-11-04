# Design Your Study

These are the steps to design the study and to build the [Strategus](https://github.com/OHDSI/Strategus)
analysis specification that `ExecuteAnalyses.R` runs. They assume you have a
protocol, that your cohorts have been designed and reviewed, and that you have
approval to execute the study.

## Study design in one page

| | |
|---|---|
| Targets | Placeholder demo ATLAS cohorts (1 ACE inhibitors, 2 ARBs); the real targets are one cohort per calendar year = everyone with a visit on 1 January |
| Outcomes | Placeholder demo ATLAS cohort: 3 first observed cough |
| Primary output | Incidence rate per 100 person-years, by calendar year, overall and by age and gender |
| Modules | CohortGenerator, CohortDiagnostics (outcome cohorts), Characterization (v4) |

There is no estimation (CohortMethod, SelfControlledCaseSeries) and no
prediction (PatientLevelPrediction) in this study.

## Download study assets

`DownloadAssets.R` downloads cohort definitions from ATLAS into `inst/`
(`Cohorts.csv`, `inst/cohorts/*.json`, `inst/sql/sql_server/*.sql`). Every
cohort in the study comes from ATLAS, so this is the only way cohorts get into
the repository - there is no hand-written cohort SQL.

To use it:

1. Set `webApiUrl` in `config.yml` to your ATLAS instance.
2. List the cohorts you want in the `cohortsToDownload` table in
   `DownloadAssets.R` (ATLAS cohort ID, local cohort ID, cohort name).
3. Run the script from the project root.

The cohorts currently listed are the placeholders from the OHDSI demo ATLAS
(`https://atlas-demo.ohdsi.org/atlas/`), so the script works as-is.

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
targetIds <- c(1, 2)
```

The cohort IDs of the target cohorts. 1 (new users of ACE inhibitors) and
2 (new users of ARBs) are **placeholders from the OHDSI demo ATLAS**; replace
them when the real target cohorts are defined.

### 2. Outcomes

```r
outcomes <- tibble::tribble(
  ~cohortId, ~cleanWindow,
  3,         365
)
```

`cohortId` is the outcome cohort ID. `cleanWindow` is the number of days that
must pass between two events before the second one counts as a new event.

**Cohort 3 (first observed cough) is a placeholder** from the OHDSI demo ATLAS. When the
real outcome cohorts exist: add them to the `cohortsToDownload` table in
`DownloadAssets.R` and run it (it regenerates `inst/Cohorts.csv` from ATLAS),
then replace the IDs here. The script stops if an outcome ID is missing from
`inst/Cohorts.csv`.

### 3. Time at risk

```r
riskWindowStart <- 1
startAnchor <- "cohort start"
riskWindowEnd <- 0
endAnchor <- "cohort end"
```

For the demo drug cohorts this means "from the day after the first exposure to
the end of the exposure", i.e. on-treatment follow-up.

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
- **CohortDiagnosticsModule** - cohort diagnostics for the outcome cohorts.
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
