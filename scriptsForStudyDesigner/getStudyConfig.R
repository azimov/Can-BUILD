################################################################################
# Read the study configuration
#
# config::get() reads a single YAML file (config.yml) and returns one profile
# from it. It has no notion of "this machine's overrides", and the file is
# checked in to git, so anything machine-specific must not live there.
#
# This helper adds that layer:
#
#   config <- getStudyConfig()
#
# returns the `default` profile from config.yml, with every value present in
# config.local.yml layered on top. config.local.yml is gitignored, so each
# participant keeps their own database host, credentials and schema names
# without ever committing them.
#
# Values not set in config.local.yml fall back to config.yml.
################################################################################

getStudyConfig <- function(projectRootFolder = getwd(),
                           profile = Sys.getenv("R_CONFIG_ACTIVE", "default")) {
  baseFile <- file.path(projectRootFolder, "config.yml")
  localFile <- file.path(projectRootFolder, "config.local.yml")

  base <- config::get(file = baseFile, config = profile)
  if (!file.exists(localFile)) {
    return(base)
  }

  local <- config::get(file = localFile, config = profile)
  # A local file written as `default:`/`local:` blocks is used as-is; a flat
  # local file (no matching profile) also works, because config::get() falls
  # back to its own `default` block.
  merged <- utils::modifyList(as.list(base), as.list(local))
  # projectRootFolder stays the project root even when overridden.
  merged$projectRootFolder <- projectRootFolder
  merged
}
