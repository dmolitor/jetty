write.csv(mtcars, "./mtcars.csv", row.names = FALSE)
write.csv(mycars, "./mycars.csv", row.names = FALSE)
env_var <- Sys.getenv("JETTY_TEST")