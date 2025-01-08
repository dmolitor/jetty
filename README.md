
<!-- README.md is generated from README.Rmd. Please edit that file -->

# jetty <img src='man/figures/logo-no-bg.png' align="right" height="139"/>

<!-- badges: start -->

[![pkgdown](https://github.com/dmolitor/jetty/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/dmolitor/jetty/actions/workflows/pkgdown.yaml)
[![R-CMD-check](https://github.com/dmolitor/jetty/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/dmolitor/jetty/actions/workflows/R-CMD-check.yaml)
[![CRAN
status](https://www.r-pkg.org/badges/version/jetty)](https://CRAN.R-project.org/package=jetty)
<!-- badges: end -->

> Execute R functions or code blocks within a Docker container.

It may be useful, in certain circumstances, to perform a computation in
a separate R process that is running within a Docker container. This
package attempts to achieve this!

## Features

- Calls an R function with arguments or a code block in a subprocess
  within a Docker container.

- Copies function arguments (as necessary) to the subprocess and copies
  the return value of the function/code block.

- Discovers and installs required packages in the Docker container at
  run-time.

- Copies error objects back from the subprocess. In general, these error
  objects do not include the stack trace from the Docker R process.
  However, if for example the error is an rlang error, it will include
  the full stack trace.

- Shows and/or collects the standard output and standard error of the
  Docker subprocess.

## Install

To install jetty from GitHub:

``` r
# install.packages("pak")
pak::pkg_install("dmolitor/jetty")
```

## Synchronous, one-off R processes in a Docker container

Use `run()` to execute an R function or code block in a new R process
within a Docker container. The results are passed back directly to the
local R session.

``` r
jetty::run(function() var(iris[, 1:4]))
#>              Sepal.Length Sepal.Width Petal.Length Petal.Width
#> Sepal.Length    0.6856935  -0.0424340    1.2743154   0.5162707
#> Sepal.Width    -0.0424340   0.1899794   -0.3296564  -0.1216394
#> Petal.Length    1.2743154  -0.3296564    3.1162779   1.2956094
#> Petal.Width     0.5162707  -0.1216394    1.2956094   0.5810063
```

### Specifying Docker container

The desired Docker container can be set via the `image` argument, and
should be specified as a string in standard Docker format. These formats
include `username/image:tag`, `username/image`, `image:tag`, and
`image`. The default choice is `r-base:{jetty:::r_version()}` which is a
bare-bones R image that mirrors the R version running locally. For
example, the following command would be executed in the official
[`r-base`](https://hub.docker.com/_/r-base) image with the latest
version of R, which comes with no packages beyond the base set
installed:

``` r
jetty::run(function() var(iris[, 1:4]), image = "r-base:latest")
```

### Passing arguments

You can pass arguments to the function by setting `args` to the list of
arguments, similar to the base `do.call` function. This is often
necessary, as the function being evaluated in the Docker R process does
not have access to variables in the parent process. For example, the
following does not work:

``` r
mycars <- cars
jetty::run(function() summary(mycars))
#> Error in (function () : object 'mycars' not found
```

But this does:

``` r
mycars <- cars
jetty::run(function(x) summary(x), args = list(mycars))
#>      speed           dist       
#>  Min.   : 4.0   Min.   :  2.00  
#>  1st Qu.:12.0   1st Qu.: 26.00  
#>  Median :15.0   Median : 36.00  
#>  Mean   :15.4   Mean   : 42.98  
#>  3rd Qu.:19.0   3rd Qu.: 56.00  
#>  Max.   :25.0   Max.   :120.00
```

### Using packages

You can use any package in the child R process, with the caveat that the
package must be installed in the Docker container. While it’s
recommended to refer to it explicitly with the `::` operator, the code
snippet can also call `library()` or `require()` and will work fine. For
example, the following code snippets both work equally well:

``` r
jetty::run(
  {
    library(Matrix);
    function(nrow, ncol) rsparsematrix(nrow, ncol, density = 1)
  },
  args = list(nrow = 10, ncol = 2)
)
#> Loading required package: Matrix
#> 10 x 2 sparse Matrix of class "dgCMatrix"
#>                   
#>  [1,] -0.460  0.73
#>  [2,]  3.200 -1.30
#>  [3,]  0.440 -1.10
#>  [4,] -0.930  2.40
#>  [5,]  0.040 -1.20
#>  [6,] -0.960  1.40
#>  [7,]  0.250  0.82
#>  [8,]  0.088  1.40
#>  [9,]  1.400 -1.20
#> [10,] -0.600 -1.20
```

and

``` r
jetty::run(
  function(nrow, ncol) Matrix::rsparsematrix(nrow, ncol, density = 1),
  args = list(nrow = 10, ncol = 2)
)
#> 10 x 2 sparse Matrix of class "dgCMatrix"
#>                   
#>  [1,] -0.920 -0.96
#>  [2,]  1.200  0.53
#>  [3,]  0.520 -0.32
#>  [4,]  0.046 -0.81
#>  [5,]  0.180  0.73
#>  [6,] -0.770  0.54
#>  [7,] -0.550 -0.60
#>  [8,] -1.300 -0.27
#>  [9,] -0.140 -1.70
#> [10,]  0.430  0.40
```

#### Installing required packages

jetty also supports installing required packages at runtime. For
example, the following code will fail because the required packages are
not installed in the Docker image:

``` r
jetty::run(
  {
    ggplot2::ggplot(mtcars, ggplot2::aes(x = hp, y = mpg)) +
      ggplot2::geom_point()
  }
)
#> Error in loadNamespace(x): there is no package called ‘ggplot2’
```

However, by setting `install_dependencies = TRUE` we can tell jetty to
discover the required packages and install them before executing the
code:

``` r
jetty::run(
  {
    ggplot2::ggplot(mtcars, ggplot2::aes(x = hp, y = mpg)) +
      ggplot2::geom_point()
  },
  install_dependencies = TRUE,
  stdout = TRUE
)
```

<img src="man/figures/README-unnamed-chunk-10-1.png" width="80%" />

**Note**: this feature uses
[`renv::dependencies`](https://rstudio.github.io/renv/reference/dependencies.html)
to discover the required packages, and won’t handle all possible
scenarios. In particular, it won’t install specific package versions
(just the latest version) and it will only install packages that are on
CRAN. Use this with care!

### Error handling

jetty copies errors from the child R process to the main R session:

``` r
jetty::run(function() 1 + "A")
#> Error in 1 + "A": non-numeric argument to binary operator
```

Although the errors themselves are propagated to the main R session, the
stack trace is (currently) not propagated. This means that calling
functions such as `traceback()` and `rlang::last_trace()` won’t be of
any help.

### Standard output and error

By default, the standard output and error of the Docker subprocess are
printed to the R console. However, since jetty uses `system2()` to
execute all Docker commands, you can specify the `stdout` and `stderr`
arguments which will be passed directly to `system2()`. For example the
following code will print a series of messages to the console:

``` r
jetty::run({for (i in 1:5) message(paste0("iter", i)); TRUE})
#> iter1
#> iter2
#> iter3
#> iter4
#> iter5
#> [1] TRUE
```

But you can discard this output by setting `stdout = FALSE`:

``` r
jetty::run({for (i in 1:5) message(paste0("iter", i)); TRUE}, stdout = FALSE)
#> [1] TRUE
```

To see more details on controlling `stdout` and `stderr`, check out the
[documentation
here](https://stat.ethz.ch/R-manual/R-devel/library/base/html/system2.html).

### .Rprofile and .Renviron

jetty also provides some support for `.Rprofile` and `.Renviron` files.
By default, jetty will search for files called “.Rprofile” and
“.Renviron” in the current working directory. If these files exist,
jetty will port them to the Docker execution environment and will
execute any code in `.Rprofile` and load all environment variables in
`.Renviron` before executing the provided R code. If the `.Rprofile`
file uses external packages, it is essential to tell jetty to install
required packages (as described above) otherwise the code will fail.

The user can explicitly provide `.Rprofile` and `.Renviron` file paths
via the `r_profile` and `r_environ` arguments. For example, the
following code will attach the `.Rprofile` found in the
`/man/scaffolding/` sub-directory of the current working directory. This
file simply uses the [praise](https://github.com/rladies/praise) package
to provide some encouragement at the start of a new R session.

``` r
four <- jetty::run(
  \() 2 + 2,
  r_profile = here::here("man/scaffolding/.Rprofile"),
  install_dependencies = TRUE
)
#> Installing package into ‘/usr/local/lib/R/site-library’
#> (as ‘lib’ is unspecified)
#> trying URL 'https://r-lib.github.io/p/pak/stable/source/linux-gnu/aarch64/src/contrib/../../../../../linux/aarch64/pak_0.8.0_R-4-4_aarch64-linux.tar.gz'
#> Content type 'application/gzip' length 8847947 bytes (8.4 MB)
#> ==================================================
#> downloaded 8.4 MB
#> 
#> * installing *binary* package ‘pak’ ...
#> * DONE (pak)
#> 
#> The downloaded source packages are in
#>  ‘/tmp/RtmpNxnaJk/downloaded_packages’
#> ✔ Updated metadata database: 3.07 MB in 8 files.
#> ✔ Updating metadata database ... done
#>  
#> → Will install 1 package.
#> → Will download 1 CRAN package (6.10 kB).
#> + praise   1.0.0 [bld][dl] (6.10 kB)
#>   
#> ℹ Getting 1 pkg (6.10 kB)
#> ✔ Got praise 1.0.0 (source) (6.10 kB)
#> ℹ Building praise 1.0.0
#> ✔ Built praise 1.0.0 (403ms)
#> ✔ Installed praise 1.0.0  (7ms)
#> ✔ 1 pkg: added 1, dld 1 (6.10 kB) [3.8s]
#> You are exquisite!
```

However, as noted above, this fails if `install_dependencies = FALSE`.

``` r
four <- jetty::run(
  \() 2 + 2,
  r_profile = here::here("man/scaffolding/.Rprofile")
)
#> Error in loadNamespace(x): there is no package called ‘praise’
```

#### Multiple .Rprofile or .Renviron files

Currently jetty only supports single `.Rprofile` or `.Renviron` files.
So, for example, if a user has a project-specific .Rprofile in the
current working directory at `./.Rprofile` and then a user-specific
.Rprofile at `~/.Rprofile`, jetty will only source `./.Rprofile` and
will ignore `~/.Rprofile`. This is a feature I plan to add before long.
