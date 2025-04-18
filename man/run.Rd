% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/run.R
\name{run}
\alias{run}
\title{Execute an R expression inside a Docker container}
\usage{
run(
  func,
  args = list(),
  image = paste0("r-base:", r_version()),
  stdout = "",
  stderr = "",
  install_dependencies = FALSE,
  r_profile = jetty_r_profile(),
  r_environ = jetty_r_environ(),
  debug = FALSE
)
}
\arguments{
\item{func}{Function object or code block to be executed in the R session
within the Docker container. It is best to reference package functions using
the \code{::} notation, and only packages installed in the Docker container are
accessible.}

\item{args}{Arguments to pass to the function. Must be a list.}

\item{image}{A string in the \code{image:tag} format specifying either a local
Docker image or an image available on DockerHub. Default image is
\code{r-base:{jetty:::r_version()}} where your R version is determined from
your local R session.}

\item{stdout, stderr}{where output to ‘stdout’ or ‘stderr’ should be sent.
Possible values are "", to the R console (the default), NULL
(discard output), FALSE (discard output), TRUE
(capture the output silently and then discard), or a
character string naming a file. See \code{\link{system2}} which this
function uses under the hood; however, note that \code{\link{system2}}
handles these options slightly differently.}

\item{install_dependencies}{A boolean indicating whether jetty should
discover packages used in your code and try to install them in the
Docker container prior to executing the provided function/expression.
In general, things will work better if the Docker image already has all
necessary packages installed.}

\item{r_profile, r_environ}{Paths specifying where jetty should search for
the .Rprofile and .Renviron files to transfer to the Docker sub-process.
By default jetty will look for files called ".Rprofile" and ".Renviron"
in the current working directory. If either file is found, they will be
transferred to the Docker sub-process and loaded before executing any
R commands. To explicitly exclude either file, set the value to
\code{NULL}. Alternatively, to exclude either file for all jetty function
calls, set the \code{JETTY_IGNORE_RPROFILE}/\code{JETTY_IGNORE_RENVIRON}
environment variable(s) to one of \code{c(TRUE, "T")} or set the R
option(s) \code{jetty.ignore.rprofile}/\code{jetty.ignore.renviron}
\code{TRUE}.}

\item{debug}{A boolean indicating whether to print out the commands that are
being executed via the shell. This is mostly helpful to see what is
happening when things start to error.}
}
\value{
Value of the evaluated expression.
}
\description{
This function is somewhat similar in spirit to
\code{callr::r()} in that the user can pass
a function (or a code block) to be evaluated. This code will
be executed within the context of a Docker container and the result will be
returned within the local R session.
}
\section{Side effects}{


It is important to note that some side effects, e.g. plotting,
may be lost since these are being screamed into the void of the Docker
container. However, the user has full control over the 'stdterr' and 'stdout'
of the R sub-process running in the Docker container, and so side effects such
as messages, warnings, and printed output can be directed to the console or
captured by the user.

It is also crucial to note that actions on the local file system will not
work with jetty sub-processes. For example, reading or writing files to/from
the local file system will fail since the R sub-process within the Docker
container does not have access to the local file system.
}

\section{Error handling}{


jetty will propagate errors from the Docker process to the main process.
That is, if an error is thrown in the Docker process, an error with the same
message will be thrown in the main process. However, because of the
somewhat isolated nature of the local process and the Docker process,
calling functions such as \code{base::traceback()} and \code{rlang::last_trace()} will
not print the callstack of the uncaught error as that has
(in its current form) been lost in the Docker void.
}

\examples{
\dontrun{
run(
  {
    mtcars <- mtcars |>
      transform(cyl = as.factor(cyl))
    model <- lm(mpg ~ ., data = mtcars)
    model
  }
)

# A code snippet that requires packages to be installed
run(
  {
    mtcars <- mtcars |> 
      dplyr::mutate(cyl = as.factor(cyl))
    model <- lm(mpg ~ ., data = mtcars)
    model
  },
  install_dependencies = TRUE
)

# This will error since the `praise` package is not installed
run(function() praise::praise())

# Explicitly tell jetty to ignore an existing .Rprofile
run(function() summary(cars), r_profile = NULL)
}

}
