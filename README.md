
<!-- README.md is generated from README.Rmd. Please edit that file -->

# jetty <img src='man/figures/logo-no-bg.png' align="right" height="139"/>

<!-- badges: start -->
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
#>  [1,]  0.039  0.270
#>  [2,]  0.460 -1.200
#>  [3,] -1.300  0.052
#>  [4,] -0.730 -0.370
#>  [5,] -0.190  1.200
#>  [6,] -0.100  1.500
#>  [7,] -0.480 -0.062
#>  [8,]  1.000 -0.045
#>  [9,]  0.690  1.200
#> [10,]  0.560  0.220
```

and

``` r
jetty::run(
  function(nrow, ncol) Matrix::rsparsematrix(nrow, ncol, density = 1),
  args = list(nrow = 10, ncol = 2)
)
#> 10 x 2 sparse Matrix of class "dgCMatrix"
#>                       
#>  [1,]  0.1700  0.06000
#>  [2,] -1.4000  0.27000
#>  [3,]  0.2200  0.49000
#>  [4,] -1.0000  1.20000
#>  [5,] -0.0019  0.32000
#>  [6,] -0.8800 -0.41000
#>  [7,] -0.0670  0.01400
#>  [8,] -2.2000 -0.37000
#>  [9,]  1.5000 -1.50000
#> [10,] -0.4700  0.00015
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

<img src="man/figures/README-unnamed-chunk-10-1.png" width="100%" />

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
