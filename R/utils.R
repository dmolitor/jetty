bindmount_temp <- function(local, docker) {
  arg <- paste0("-v ", local, ":", docker)
  arg
}

check_args <- function(args) {
  if (is.list(args) && !is.data.frame(args)) return(invisible(args))
  rlang::abort("`args` must be a list")
}

cmd_message <- function(cmd_args) {
  message(
    paste0(
      "Executing command:\n",
      paste0(c("docker", cmd_args), collapse = " ")
    )
  )
}

docker_installed <- function() {
  installed <- Sys.which("docker")
  if (installed == "") installed <- FALSE else installed <- TRUE
  installed
}

handle_error <- function(x) {
  if (inherits(x, "error")) stop(x)
  invisible(x)
}

jetty_r_environ <- function() {
  env_var <- as.logical(Sys.getenv("JETTY_IGNORE_RENVIRON"))
  opt_var <- getOption("jetty.ignore.renviron")
  if (!isTRUE(env_var) && !isTRUE(opt_var)) {
    return(file.path(getwd(), ".Renviron"))
  } else {
    return(NULL)
  }
}

jetty_r_profile <- function() {
  env_var <- as.logical(Sys.getenv("JETTY_IGNORE_RPROFILE"))
  opt_var <- getOption("jetty.ignore.rprofile")
  if (!isTRUE(env_var) && !isTRUE(opt_var)) {
    return(file.path(getwd(), ".Rprofile"))
  } else {
    return(NULL)
  }
}

jetty_temp_dir <- function() "/jetty/tmp/"

prof_env_bindmounts <- function(r_profile, r_environ) {
  r_prof_mount <- r_env_mount <- r_prof_load <- r_env_load <- NULL
  if (!is.null(r_profile)) {
    r_profile <- normalizePath(r_profile, mustWork = FALSE)
    if (file.exists(r_profile)) {
      r_prof_mount <- paste0("-v ", r_profile, ":", "/jetty/.Rprofile")
      r_prof_load <- "source('/jetty/.Rprofile')"
    } 
  }
  if (!is.null(r_environ)) {
    r_environ <- normalizePath(r_environ, mustWork = FALSE)
    if (file.exists(r_environ)) {
      r_env_mount <- paste0("-v ", r_environ, ":", "/jetty/.Renviron")
      r_env_load <- "readRenviron('/jetty/.Renviron')"
    }
  }
  return(list(r_prof_mount, r_env_mount, r_prof_load, r_env_load))
}

r_version <- function() {
  paste0(R.version$major, ".", R.version$minor)
}

stop_if_not_installed <- function() {
  is_installed <- docker_installed()
  if (!is_installed) {
    rlang::abort(
      c(
        "Docker is not installed.",
        "i" = "Visit https://docs.docker.com/get-docker/ to get started!"
      ),
      call = parent.frame()
    )
  }
}

take_stock <- function(expr, install_dependencies, temp_dir, r_profile, is_expression = TRUE) {
  if (install_dependencies) {
    dependencies_rprofile <- NULL
    if (is_expression) {
      temp_R <- file.path(temp_dir, "jetty.R")
      writeLines(rlang::expr_text(expr), temp_R)
      on.exit(if (file.exists(temp_R)) file.remove(temp_R), add = TRUE)
    } else {
      temp_R <- expr
    }
    dependencies_expr <- renv::dependencies(temp_R, quiet = TRUE)$Package
    if (length(dependencies_expr) == 0) {
      dependencies_expr <- NULL
    }
    if (!is.null(r_profile) && file.exists(r_profile)) {
      dependencies_rprofile <- renv::dependencies(r_profile, quiet = TRUE)$Package
      if (length(dependencies_rprofile) == 0) {
        dependencies_rprofile <- NULL
      }
    }
    dependencies <- c(dependencies_expr, dependencies_rprofile)
  } else {
    dependencies <- NULL
  }
  return(dependencies)
}
