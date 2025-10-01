# jetty 0.2.2

* Improves `pak` setup so that, whenever possible, `pak` will install package
binaries instead of building from source.

# jetty 0.2.1

* Improves error messages if the underlying Docker process throws an error.
* Allows the user greater control over .Renviron and .Rprofile files:
    - Allows users to explicitly ignore these files by setting the arguments
      `r_profile = NULL` or `r_environ = NULL`.
    - Allows users to ignore these via environment variables or R options.

# jetty 0.2.0

- **Execute an R script in a Docker container**:
    jetty now supports executing an R script in a Docker container via the
    `run_script()` function. A particularly important argument
    is the `context` argument. This user should specify this
    as the filepath to a directory that serves as the script's
    execution context. Specifically, this directory will be mounted to the
    Docker container and, as a result, this script will have access to all
    files/directories contained within the context. The script's execution will
    fail if it attempts to interact with any files/directories
    outside the provided context directory.
    **Note**: this is a feature that is only designed to work
    well with MacOS and Linux and will most likely crap out if used on Windows.

# jetty 0.1.0

* Initial CRAN submission.
