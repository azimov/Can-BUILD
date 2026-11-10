################################################################################
# Read the study configuration
#
# config::get() reads a single YAML file and returns one profile from it. It
# insists that every file has a `default:` block, and it has no notion of
# "this machine's overrides". config.yml is checked in, so anything
# machine-specific must live elsewhere.
#
# getStudyConfig() adds that layer:
#
#   config <- getStudyConfig()
#
# returns the settings from config.yml with every value in config.local.yml
# layered on top. config.local.yml is gitignored, so each participant keeps
# their own database host, credentials and schema names without committing them.
#
# config.local.yml may be written as:
#
#   local:            # block named after R_CONFIG_ACTIVE
#     cdmDatabaseSchema: "..."
#
#   default:          # always applied
#     cdmDatabaseSchema: "..."
#
#   cdmDatabaseSchema: "..."   # flat, no blocks at all
#
# Any of the three works. Values not set locally fall back to config.yml.
################################################################################

getStudyConfig <- function(projectRootFolder = getwd(),
                           profile = Sys.getenv("R_CONFIG_ACTIVE", "default")) {
  baseFile <- file.path(projectRootFolder, "config.yml")
  localFile <- file.path(projectRootFolder, "config.local.yml")

  base <- config::get(file = baseFile, config = profile)
  if (!file.exists(localFile)) {
    return(base)
  }

  # Read the local file directly rather than via config::get(), which requires a
  # `default:` block that an override file usually does not have.
  # eval.expr = TRUE so that `!expr` values (e.g. createConnectionDetails(...))
  # are evaluated.
  local <- tryCatch(
    yaml::read_yaml(localFile, eval.expr = TRUE),
    error = function(e) {
      stop("Could not read ", localFile, ": ", conditionMessage(e), call. = FALSE)
    }
  )
  if (is.null(local) || length(local) == 0) {
    return(base)
  }

  # Pick the block for the active profile. When R_CONFIG_ACTIVE is unset the
  # profile is "default", but an override file normally writes its settings
  # under `local:`, so prefer `local:` and fall back to `default:`. If neither
  # block is present the file is a flat set of settings and is used as-is.
  if (is.list(local[["local"]])) {
    local <- local[["local"]]
  } else if (is.list(local[[profile]])) {
    local <- local[[profile]]
  } else if (is.list(local[["default"]])) {
    local <- local[["default"]]
  }
  if (is.null(local) || length(local) == 0) {
    return(base)
  }

  merged <- utils::modifyList(as.list(base), local)
  # projectRootFolder always stays the project root, even if overridden.
  merged$projectRootFolder <- projectRootFolder
  merged
}
