bindmount_home <- function() {
  # TODO: Determine if this is the drive we want to mount
  home_dir <- path.expand("~")
  arg <- paste0("-v ", home_dir, ":", home_dir, "/:rw")
  arg
}

bindmount_temp <- function(dir) {
  arg <- paste0("-v ", dir, ":", dir, "/:rw")
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
