#' Execute an R script inside a Docker container
#'
#' This function is somewhat similar in spirit to
#' \code{callr::rscript()} in that the user can specify
#' an R script to be executed within the context of a Docker container.
#' 
#' \bold{NOTE}: this feature is still fairly experimental. It will \emph{NOT}
#' work on Windows. It is only made to be compatible with MacOS and Linux.
#'
#' @section Interaction with the local file system:
#' 
#' The user will be asked to specify a \code{context} (local directory)
#' for executing the R script. jetty mounts this directory to the Docker
#' container, allowing the script to interact with files within it
#' (read/write). Attempts to access files outside the context directory
#' will cause the script to fail. Ensure the context directory includes
#' all files needed for the script to run.
#'
#' @section Error handling:
#'
#' \code{run_script} will handle errors using the same mechanism as
#' \code{\link{run}}. See that documentation for more details.
#'
#' @param file A character string giving the pathname of the file to read from.
#' @param ... Additional arguments to be passed directly to \code{\link{source}}.
#' @param context The pathname of the directory to serve as the execution context.
#'   This directory will be mounted to the Docker container, which
#'   means that the script will have access to all files/directories that are
#'   within the context directory. The context will also serve as the working
#'   directory from which the script is executed. It is crucial to note that the
#'   script will NOT be able to access any files/directories that are outside the
#'   scope of the context directory. The default value is the directory that
#'   \code{file} is contained in.
#' @param image A string in the \code{image:tag} format specifying either a local
#'   Docker image or an image available on DockerHub. Default image is
#'   \code{r-base:{jetty:::r_version()}} where your R version is determined from
#'   your local R session.
#' @param stdout,stderr where output to ‘stdout’ or ‘stderr’ should be sent.
#'   Possible values are "", to the R console (the default), NULL
#'   (discard output), FALSE (discard output), TRUE
#'   (capture the output silently and then discard), or a
#'   character string naming a file. See \code{\link{system2}} which this
#'   function uses under the hood; however, note that \code{\link{system2}}
#'   handles these options slightly differently.
#' @param install_dependencies A boolean indicating whether jetty should
#'   discover packages used in your code and try to install them in the
#'   Docker container prior to executing the provided function/expression.
#'   In general, things will work better if the Docker image already has all
#'   necessary packages installed.
#' @param r_profile,r_environ Paths specifying where jetty should search for
#'   the .Rprofile and .Renviron files to transfer to the Docker sub-process.
#'   By default jetty will look for files called ".Rprofile" and ".Renviron"
#'   in the current working directory. If either file is found, they will be
#'   transferred to the Docker sub-process and loaded before executing any
#'   R commands. To explicitly exclude either file, set the value to `NULL`.
#'   Alternatively, to exclude either file for all jetty function calls,
#'   set the `JETTY_IGNORE_RPROFILE`/`JETTY_IGNORE_RENVIRON` environment
#'   variable(s) to one of `c(TRUE, "T")` or set the R option(s)
#'   `jetty.ignore.rprofile`/`jetty.ignore.renviron` to `TRUE`.
#' @param debug A boolean indicating whether to print out the commands that are
#'   being executed via the shell. This is mostly helpful to see what is
#'   happening when things start to error.
#'
#' @return The value of the last evaluated expression in the script.
#' @examples
#' \dontrun{
#' # Execute a simple script that has no package dependencies
#' run_script(file = here::here("code/analysis_script.R"))
#' 
#' # Execute a script that needs access to the entire analysis directory
#' run_script(
#'   file = here::here("code/analysis_script.R"),
#'   context = here::here()
#' )
#' 
#' # Execute a script that needs access to the entire analysis directory
#' # and relies on external packages
#' run_script(
#'   file = here::here("code/analysis_script.R"),
#'   context = here::here(),
#'   install_dependencies = TRUE
#' )
#' 
#' # Execute a script and explicitly ignore an existing .Rprofile
#' run_script(
#'   file = here::here("code/analysis_script.R"),
#'   r_profile = NULL
#' )
#' }
#'
#' @export
run_script <- function(
  file,
  ...,
  context = dirname(file),
  image = paste0("r-base:", r_version()),
  stdout = "",
  stderr = "",
  install_dependencies = FALSE,
  r_profile = jetty_r_profile(),
  r_environ = jetty_r_environ(),
  debug = FALSE
) {
  file <- normalizePath(file, mustWork = TRUE)
  context <- normalizePath(context, mustWork = TRUE)
  args <- rlang::list2(file = file, ...)
  check_args(args)
  # Handle writing of args to serialized temp files
  temp_dir <- tempdir()
  temp_in_local <- tempfile(tmpdir = temp_dir, fileext = ".RDS")
  temp_in_docker <- file.path(jetty_temp_dir(), basename(temp_in_local))
  temp_out_local <- tempfile(tmpdir = temp_dir, fileext = ".RDS")
  temp_out_docker <- file.path(jetty_temp_dir(), basename(temp_out_local))
  on.exit(if (file.exists(temp_in_local)) file.remove(temp_in_local), add = TRUE)
  on.exit(if (file.exists(temp_out_local)) file.remove(temp_out_local), add = TRUE)
  saveRDS(object = args, file = temp_in_local)
  # Capture the expression to be evaluated
  expr <- rlang::expr({ source })
  # If requested, write the code to an R file and examine for dependencies
  dependencies <- take_stock(
    expr = file,
    install_dependencies = install_dependencies,
    temp_dir = temp_dir,
    r_profile = r_profile,
    is_expression = FALSE
  )
  # Generate the bind mounts and loading commands for .Rprofile, .Renviron, and `context`
  file_bindmount <- paste0("-v ", context, ":", context)
  rprof_env_bindmounts <- prof_env_bindmounts(r_profile, r_environ)
  rprof_bindmount <- rprof_env_bindmounts[[1]]
  rprof_load <- rprof_env_bindmounts[[3]]
  renv_bindmount <- rprof_env_bindmounts[[2]]
  renv_load <- rprof_env_bindmounts[[4]]
  # Parse the code into the corresponding docker command
  expr <- command_shell_prep(
    !!expr,
    rprof = rprof_load,
    renv = renv_load,
    temp_out = temp_out_docker,
    temp_in = temp_in_docker,
    dependencies = dependencies,
    context = context
  )
  # Generate additional arguments to pass to `docker run ...`
  temp_dir_mount <- bindmount_temp(temp_dir, jetty_temp_dir())
  cmd_args <- c(
    "run",
    "-t",
    "--rm",
    file_bindmount,
    temp_dir_mount,
    rprof_bindmount,
    renv_bindmount,
    image,
    "Rscript",
    "-e",
    expr
  )
  if (debug) cmd_message(cmd_args)
  out <- docker_command(args = cmd_args, stdout = stdout, stderr = stderr)
  result <- readRDS(temp_out_local)
  handle_error(result)
  invisible(result$value)
}
