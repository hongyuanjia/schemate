#!/usr/bin/env Rscript

script_arg <- commandArgs(FALSE)
script_file <- sub("^--file=", "", script_arg[startsWith(script_arg, "--file=")][[1L]])
repo <- normalizePath(file.path(dirname(normalizePath(script_file, mustWork = TRUE)), ".."), mustWork = TRUE)

old <- getwd()
on.exit(setwd(old), add = TRUE)
setwd(repo)
system2("git", c("config", "core.hooksPath", ".githooks"))
message("Installed schemate git hooks from .githooks")
