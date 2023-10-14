# jetty

> Execute R functions or code blocks within a Docker container.

It may be useful, in certain circumstances, to perform a computation in a 
separate R process that is running within a Docker container. This package
attempts to achieve this!

## Features

✅ Call an R function with arguments or a code block in a subprocess 
within a Docker container

✅ Copies function arguments (as necessary) to the subprocess and copies the 
return value of the function/code block

✅ Copies error objects back from the subprocess.

❌ Error objects include stack trace.

✅ Shows the standard output and standard error of the subprocess. 

❌ Collects the standard output and standard error.

❌ Call the function/code block asynchronously (in the background)

❌ Supports persistent R/Docker subprocesses.

## Install

``` r
# install.packages("remotes")
remotes::install_github("dmolitor/jetty")
```

# Examples

Use `run()` to run an R function in a new R process in a Docker container.
The results are passed back seamlessly.

``` r
jetty::run(function() var(iris[, 1:4]))
```

## Passing arguments

You can pass arguments to the function by setting args to the list of arguments.
This is often necessary as these arguments are explicitly copied to the child
process, whereas the evaluated function cannot refer to variables in the parent.
For example, the following does not work:
```r
mycars <- cars
jetty::run(function() summary(mycars))
```

But this does:
```r
mycars <- cars
callr::r(function(x) summary(x), args = list(mycars))
```
