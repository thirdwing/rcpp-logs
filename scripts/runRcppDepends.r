#!/usr/bin/r

cat("Started at ", format(Sys.time()), "\n")
pkg <- "Rcpp"
cat(pkg, " version is ", packageDescription(pkg)$Version, "\n")

## use a test-local directory, install Rcpp, RcppArmadillo, ... there
## this will work for sub-shells such as the ones started by system() below
if (!file.exists("/tmp/RcppDepends")) dir.create("/tmp/RcppDepends")
if (!file.exists("/tmp/RcppDepends/lib")) dir.create("/tmp/RcppDepends/lib")
loclib <- "/tmp/RcppDepends/lib"
Sys.setenv("R_LIBS_USER"="/tmp/RcppDepends/lib")
#Sys.setenv("CC"="gcc")   ## needed for a bad interaction between autoconf and llvm on Ubuntu 13.10
#Sys.setenv("CXX"="g++")  ## idem

r <- getOption("repos")
r["CRAN"] <- "http://cran.rstudio.com"
r["BioCsoft"] <- "http://www.bioconductor.org/packages/release/bioc"
options(repos = r)

## for the borked src/Makevars of ExactNumCI
Sys.setenv("BOOSTLIB"="/usr/include")

setwd("/tmp/RcppDepends")

## clean old lib or repo files in /tmp
invisible(sapply(list.files("/tmp", "(repos|lib).*rds$", full.names=TRUE), unlink))

IP <- installed.packages(lib.loc=loclib) 
AP <- available.packages(contrib.url(r["CRAN"]),filter=list())	# available package at CRAN
rcppset <- sort(unname(AP[unique(c(grep("Rcpp", as.character(AP[,"Depends"])),
                                   grep("Rcpp", as.character(AP[,"LinkingTo"])),
                                   grep("Rcpp", as.character(AP[,"Imports"])))),"Package"]))

exclset <- c("cqrReg",          # requires Rmosek which require Mosek which is commercial
             "WideLM")

rcppset <- rcppset[ ! rcppset %in% exclset ]

#if (grep("transnet", rcppset)) {        ## not really an Rcpp user
#    rcppset <- rcppset[ ! grepl("transnet", rcppset) ]
#}
if (grep("BioGeoBEARS", rcppset)) {     ## indirect match, no need to test
    rcppset <- rcppset[ ! grepl("BioGeoBEARS", rcppset) ]
}
#if (grep("quadrupen", rcppset)) {       ## takes hours, skipping
#    rcppset <- rcppset[ ! grepl("quadrupen", rcppset) ]
#}
#if (grep("roxygen2", rcppset)) {        ## seems to hang for reasons that are unclear on its tests
#    rcppset <- rcppset[ ! grepl("roxygen2", rcppset) ]
#}
#if (grep("dplyr", rcppset)) {           ## confuses Suggests: and Depends:
#    rcppset <- rcppset[ ! grepl("dplyr", rcppset) ]
#}
#if (grep("WideLM", rcppset)) {          ## needs working NVidia support
#    rcppset <- rcppset[ ! grepl("WideLM", rcppset) ]
#}

print(rcppset)

res <- data.frame(pkg=rcppset, res=NA)

#for (pi in 1:nrow(res)) {
#lres <- mclapply(1:nrow(res), mc.cores = 4, FUN=function(pi) {
lres <- lapply(1:nrow(res), FUN=function(pi) {
    p <- rcppset[pi]
    i <- which(AP[,"Package"]==p)
    pkg <- paste(AP[i,"Package"], "_", AP[i,"Version"], ".tar.gz", sep="")
    pathpkg <- paste(AP[i,"Repository"], "/", pkg, sep="")

    ipidx <- which(IP[,"Package"] == p)
    if ((length(ipidx) == 0) || (IP[ipidx,"Version"] != AP[i,"Version"])) {
        install.packages(p, lib=loclib)
    }
    
    if (!file.exists(pkg)) {
        ## we got random download failures once in a while, so if running locally, use CRANberries-created mirror
        localPath <- paste("/home/edd/cranberries/sources/", pkg, sep="")
        if (file.exists(localPath)) {
            file.copy(localPath, ".")
        } else {
            download.file(pathpkg, pkg, quiet=TRUE)
        }
    }

    rc <- system(paste("xvfb-run --server-args=\"-screen 0 1024x768x24\" ",
                       "R CMD check --no-manual --no-vignettes ", pkg, " > ", pkg, ".log", sep=""))
    res[pi, "res"] <- rc
    cat("\n\nRESULT for", pkg, ":", ifelse(rc==0, "success", "failure"), "\n\n\n")
    res[pi, ]
})

res <- do.call(rbind, lres)
print(res)
print(table(res[,"res"]))
write.table(res, file=paste("result-", strftime(Sys.time(), "%Y%m%d-%H%M%S"), ".txt", sep=""), sep=",")
save(res, file=paste("result-", strftime(Sys.time(), "%Y%m%d-%H%M%S"), ".RData", sep=""))
cat("Ended at ", format(Sys.time()), "\n")
