# pod
 Execute R expressions within the context of a Docker container.

## Install
```r
# install.packages("remotes")
remotes::install_github("dmolitor/pod")
```

# Example
```r
library(pod)

mtcars_model <- run(
  func = {
    mtcars <- mtcars |>
      transform(cyl = as.factor(cyl))
    model <- lm(mpg ~ ., data = mtcars)
    model
  },
  image = "r-base:4.2.0"
)

summary(mtcars_model)
#> 
#> Call:
#> lm(formula = mpg ~ ., data = mtcars)
#> 
#> Residuals:
#>     Min      1Q  Median      3Q     Max 
#> -3.4734 -1.3794 -0.0655  1.0510  4.3906 
#> 
#> Coefficients:
#>             Estimate Std. Error t value Pr(>|t|)  
#> (Intercept) 17.81984   16.30602   1.093   0.2875  
#> cyl6        -1.66031    2.26230  -0.734   0.4715  
#> cyl8         1.63744    4.31573   0.379   0.7084  
#> disp         0.01391    0.01740   0.799   0.4334  
#> hp          -0.04613    0.02712  -1.701   0.1045  
#> drat         0.02635    1.67649   0.016   0.9876  
#> wt          -3.80625    1.84664  -2.061   0.0525 .
#> qsec         0.64696    0.72195   0.896   0.3808  
#> vs           1.74739    2.27267   0.769   0.4510  
#> am           2.61727    2.00475   1.306   0.2065  
#> gear         0.76403    1.45668   0.525   0.6057  
#> carb         0.50935    0.94244   0.540   0.5948  
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
#> 
#> Residual standard error: 2.582 on 20 degrees of freedom
#> Multiple R-squared:  0.8816, Adjusted R-squared:  0.8165 
#> F-statistic: 13.54 on 11 and 20 DF,  p-value: 5.722e-07
```

This is exactly the output one would expect. Yay!!! 🎉
