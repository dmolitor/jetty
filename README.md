
<!-- README.md is generated from README.Rmd. Please edit that file -->

# jetty

<!-- badges: start -->
<!-- badges: end -->

> Execute R functions or code blocks within a Docker container.

It may be useful, in certain circumstances, to perform a computation in
a separate R process that is running within a Docker container. This
package attempts to achieve this!

## Features

- [x] Call an R function with arguments or a code block in a subprocess
  within a Docker container

- [x] Copies function arguments (as necessary) to the subprocess and
  copies the return value of the function/code block

- [x] Copies error objects back from the subprocess.

- [] Error objects include stack trace.

- [x] Shows the standard error and (to some degree) standard output of
  the subprocess.

- [] Collects the standard output and standard error.

- [] Call the function/code block asynchronously (in the background)

- [] Supports persistent R/Docker subprocesses.

## Install

``` r
# install.packages("remotes")
remotes::install_github("dmolitor/jetty")
```

## Usage

Use `run()` to execute an R function or code block in a new R process
within a Docker container. The results are passed back directly to the
local R session.

``` r
jetty::run(function() summary(cars))
#>      speed           dist       
#>  Min.   : 4.0   Min.   :  2.00  
#>  1st Qu.:12.0   1st Qu.: 26.00  
#>  Median :15.0   Median : 36.00  
#>  Mean   :15.4   Mean   : 42.98  
#>  3rd Qu.:19.0   3rd Qu.: 56.00  
#>  Max.   :25.0   Max.   :120.00
```

### Specifying Docker container

The desired Docker container can be set via the `image` argument, and
should be specified as a string in standard Docker format. These formats
include `username/image:tag`, `usename/image`, `image:tag`, and `image`.
The default choice is `r-base:{local R version}` which is a bare-bones R
image that mirrors the R version running locally. For example, the
following command would be executed in the
[`rocker/tidyverse`](https://rocker-project.org/images/versioned/rstudio.html)
image, which comes with the tidyverse (among others) already installed:

``` r
jetty::run(function() summary(cars), image = "rocker/tidyverse")
```

### Passing arguments

You can pass arguments to the function by setting `args` to the list of
arguments, similar to the base `do.call` function.

Note that the function being evaluated in `jetty::run` does not have
access to variables in the parent process. If the function relies on
specific variables, they must be passed in via `args`. For example, the
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

You can use any package in the child R process, with the major caveat
that the package must be installed in the Docker container. While it’s
recommended to refer to it explicitly with the `::` operator, the code
snippet can also call `library()` or `require()` and will work fine. For
example, the following code snippets should be identical:

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
#>  [1,]  0.69  0.520
#>  [2,] -1.30  1.700
#>  [3,] -0.57 -0.140
#>  [4,]  0.79 -0.047
#>  [5,] -0.91 -0.370
#>  [6,] -0.16  1.400
#>  [7,]  1.00 -0.018
#>  [8,]  0.19 -0.850
#>  [9,] -1.80  1.300
#> [10,]  0.15  1.000
```

and

``` r
jetty::run(
  function(nrow, ncol) Matrix::rsparsematrix(nrow, ncol, density = 1),
  args = list(nrow = 10, ncol = 2)
)
#> 10 x 2 sparse Matrix of class "dgCMatrix"
#>                    
#>  [1,] -1.800  0.072
#>  [2,]  0.260  0.230
#>  [3,]  0.540  1.600
#>  [4,] -1.700 -0.450
#>  [5,] -0.087  0.530
#>  [6,] -0.340  0.950
#>  [7,]  0.290  0.540
#>  [8,] -0.780  1.600
#>  [9,] -1.500  0.220
#> [10,]  0.270 -0.580
```

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

This is a little weird at the moment. All messages and warnings
currently surface, but printed output doesn’t show up. Still under
construction…

Currently, jetty won’t capture the standard error/output and direct it
anywhere.

## Where it’s headed

Maybe nowhere? This is still a relatively rough-shod implementation, and
it’s not totally clear to me what use-case it fills. However, it *feels*
like it should be useful somehow.
