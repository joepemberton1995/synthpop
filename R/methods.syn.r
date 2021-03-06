###-----print.synds--------------------------------------------------------

print.synds <- function(x, ...){
  cat("Call:\n($call) ")
  print(x$call)
  cat("\nNumber of synthesised data sets: \n($m) ",x$m,"\n")  
  if (x$m == 1) {
    cat("\nFirst rows of synthesised data set: \n($syn)\n")
    print(head(x$syn))
  } else {
    cat("\nFirst rows of first synthesised data set: \n($syn)\n")
    print(head(x$syn[[1]]))
  }    
  cat("...\n")
  cat("\nSynthesising methods: \n($method)\n")
  print(x$method)
  cat("\nOrder of synthesis: \n($visit.sequence)\n")
  print(x$visit.sequence)
  cat("\nMatrix of predictors: \n($predictor.matrix)\n")
  print(x$predictor.matrix)     
  invisible(x)
}


###-----summary.synds------------------------------------------------------

summary.synds <- function(object, msel = NULL, 
  maxsum = 7, digits = max(3, getOption("digits") - 3), ...){
  if (!is.null(msel) & !all(msel %in% (1:object$m))) stop("Invalid synthesis number(s)", call. = FALSE)

  sy <- list(m = object$m, msel = msel, method = object$method)

  if (object$m == 1) {
    sy$result <- summary(object$syn,...)
  } else if (is.null(msel)) {
    zall <- vector("list",object$m) 
    for (i in 1:object$m) zall[[i]] <- lapply(object$syn[[i]], summary,
      maxsum = maxsum, digits = digits, ...)
    zall.df <- Reduce(function(x,y) mapply("rbind",x,y),zall)
    meanres <- lapply(zall.df, function(x) apply(x,2,mean))
    sy$result <- summary.out(meanres)
  } else if (length(msel) == 1) {
    sy$result <- summary(object$syn[[msel]],...)
  } else {
    for (i in (1:length(msel))) {
      sy$result[[i]] <- summary(object$syn[[msel[i]]],...)
    }
  }
  class(sy) <- "summary.synds"
  return(sy)
}


###-----print.summary.synds------------------------------------------------

print.summary.synds <- function(x, ...){

 if (x$m == 1) {
   cat("Synthetic object with one synethesis using methods:\n")
   print(x$method)
   cat("\n")
   print(x$result)
 } else if (is.null(x$msel)) {
   cat("Synthetic object with ",x$m," syntheses using methods:\n",sep = "")
   print(x$method)
   cat("\nSummary (average) for all synthetic data sets:\n",sep = "")
   print(x$result)  
 } else if (length(x$msel) == 1) {
   cat("Synthetic object with ",x$m," syntheses using methods:\n",sep = "")
   print(x$method)
   cat("\nSummary for synthetic data set ",x$msel,":\n",sep = "")
   print(x$result)
 } else {
   cat("Synthetic object with ",x$m," syntheses using methods:\n",sep = "")
   print(x$method)
   for (i in (1:length(x$msel))) {
     cat("\nSummary for synthetic data set ",x$msel[i],":\n",sep = "")
     print(x$result[[i]])
   }
 }
 invisible(x)
}


###-----mcoefvar--------------------------------------------------
# Arrange coefficients from all m syntheses in a matrix
# (same with their variances). 
# [used in lm.synds and glm.synds function]

mcoefvar <- function(analyses, ...) {
  m <- length(analyses)
  if (m == 1) {
    matcoef <- mcoefavg <- analyses[[1]]$coefficients[,1]
    matvar  <- mvaravg  <- analyses[[1]]$coefficients[,2]^2
  } else {
    namesbyfit <- lapply(lapply(analyses,coefficients),rownames)
    allnames <- Reduce(union,namesbyfit)
    matcoef <- matvar <- matrix(NA, m, length(allnames))
    dimnames(matcoef)[[2]] <- dimnames(matvar)[[2]] <- allnames
    for (i in 1:m) {
      pos <- match(namesbyfit[[i]],allnames)
      matcoef[i,pos] <- analyses[[i]]$coefficients[,1]
      matvar[i,pos] <- analyses[[i]]$coefficients[,2]^2
    }
    mcoefavg <- apply(matcoef, 2, mean, na.rm = TRUE)
    mvaravg  <- apply(matvar,  2, mean, na.rm = TRUE)
    #bm <- apply(matcoef,2,var) not needed xpt for partial synthesis
  }
  if (m > 1) rownames(matcoef) <- rownames(matvar) <- paste0("syn=", 1:m)
  return(list(mcoef    = matcoef,  mvar    = matvar, 
              mcoefavg = mcoefavg, mvaravg = mvaravg))
}


###-----lm.synds-----------------------------------------------------------

lm.synds <- function(formula, data, ...)
{
 if (!class(data) == "synds") stop("Data must have class synds\n")
 if (is.matrix(data$method)) data$method <- data$method[1,]
 if (is.matrix(data$visit.sequence)) data$visit.sequence <- data$visit.sequence[1,]
 if (data$m > 1) vars <- names(data$syn[[1]])  else  vars <- names(data$syn)  
 if (data$method[names(data$method) == all.vars(formula)[1]] == "" ) cat("\n\nNote: Your response variable is not synthesised. The compare\nmethod for evaluating lack-of-fit and a summary of your model\nwith population.inference = TRUE should use incomplete = TRUE\n(see vignette on inference for details).\n\n")
 
 # Check validity of inference from vars not in visit sequence or with method ""
 checkinf(vars, formula, data$visit.sequence, data$method)  

 call <- match.call()
 fitting.function <- "lm"
 analyses <- as.list(1:data$m)

 # do the repated analysis, store the result without data
 if (data$m == 1) {
   analyses[[1]] <- summary(lm(formula, data = data$syn,...))
 } else {
   for (i in 1:data$m) {
     analyses[[i]] <- summary(lm(formula, data = data$syn[[i]],...))
   }
 }
 allcoefvar <- mcoefvar(analyses = analyses)
      
 # return the complete data analyses as a list of length m
 object <- list(call = call, mcoefavg = allcoefvar$mcoefavg, 
             mvaravg = allcoefvar$mvaravg, analyses = analyses,  
             fitting.function = fitting.function,
             n = data$n, k = data$k, proper = data$proper, 
             m = data$m, method = data$method, 
             mcoef = allcoefvar$mcoef, mvar = allcoefvar$mvar)
 class(object) <- "fit.synds"
 return(object)
}


###-----glm.synds----------------------------------------------------------

glm.synds <- function(formula, family = "binomial", data, ...)
{
 if (!class(data) == "synds") stop("Data must have class synds\n")
 if (is.matrix(data$method)) data$method <- data$method[1,]
 if (is.matrix(data$visit.sequence)) data$visit.sequence <- data$visit.sequence[1,]
 if (data$m > 1) vars <- names(data$syn[[1]])  else  vars <- names(data$syn)  
 if (data$method[names(data$method) == all.vars(formula)[1]] == "" ) cat("\n\nNote: Your response variable is not synthesised. The compare\nmethod for evaluating lack-of-fit and a summary of your model\nwith population.inference = TRUE should use incomplete = TRUE\n(see vignette on inference for details).\n\n")

 # Check validity of inference from vars not in visit sequence or with method ""
 checkinf(vars, formula, data$visit.sequence, data$method)  

 call <- match.call()
 fitting.function <- "glm"
 analyses <- as.list(1:data$m)
 
 # do the repated analysis, store the result without data
 if (data$m == 1) {
   analyses[[1]] <- summary(glm(formula,data = data$syn, family = family, ...))
 } else {
   for (i in 1:data$m) {
     analyses[[i]] <- summary(glm(formula,data = data$syn[[i]], family = family, ...))
   }
 }
 allcoefvar <- mcoefvar(analyses = analyses)
 
 # return the complete data analyses as a list of length m
 object <- list(call = call, mcoefavg = allcoefvar$mcoefavg, 
             mvaravg = allcoefvar$mvaravg, analyses = analyses,  
             fitting.function = fitting.function,
             n = data$n, k = data$k, proper = data$proper, 
             m = data$m, method = data$method, 
             mcoef = allcoefvar$mcoef, mvar = allcoefvar$mvar)
 class(object) <- "fit.synds"
 return(object)
}


###-----multinom.synds-----------------------------------------------------

multinom.synds <- function(formula, data, ...)
{
  if (!class(data) == "synds") stop("Data must have class 'synds'.\n")
  if (is.matrix(data$method)) data$method <- data$method[1,]
  if (is.matrix(data$visit.sequence)) data$visit.sequence <- data$visit.sequence[1,]
  if (data$m > 1) vars <- names(data$syn[[1]]) else  vars <- names(data$syn)  
  if (data$method[names(data$method) == all.vars(formula)[1]] == "" ) cat("\n\nNote: Your response variable is not synthesised. The compare\nmethod for evaluating lack-of-fit and a summary of your model\nwith population.inference = TRUE should use incomplete = TRUE\n(see vignette on inference for details).\n\n")
  
  # Check validity of inference from vars not in visit sequence or with method ""
  checkinf(vars, formula, data$visit.sequence, data$method)  
  
  call <- match.call()
  fitting.function <- "multinom"
  analyses <- as.list(1:data$m)
  
  # do the repated analysis, store the result without data
  for (i in 1:data$m) {
    if (data$m == 1) fit <- multinom(formula, data = data$syn, Hess = TRUE, ...)
    else fit <- multinom(formula, data = data$syn[[i]], Hess = TRUE, ...)
    ss <- summary(fit)
    analyses[[i]] <- list(coefficients = cbind(as.vector(t(ss$coefficients)),
                                               as.vector(t(ss$standard.errors)),
                                               as.vector(t(ss$coefficients)/t(ss$standard.errors))))
    dd <- dimnames(t(ss$coefficients))
    dimnames(analyses[[i]]$coefficients) <- list(paste(rep(dd[[2]], each = length(dd[[1]])),
                                                       rep(dd[[1]], length(dd[[2]])), sep = ":"),
                                                       c("Estimate", "se", "z value"))
  }
  allcoefvar <- mcoefvar(analyses = analyses)
  
  # return the complete data analyses as a list of length m
  object <- list(call = call, mcoefavg = allcoefvar$mcoefavg, 
                 mvaravg = allcoefvar$mvaravg, analyses = analyses,  
                 fitting.function = fitting.function,
                 n = data$n, k = data$k, proper = data$proper, 
                 m = data$m, method = data$method, 
                 mcoef = allcoefvar$mcoef, mvar = allcoefvar$mvar)
  class(object) <- "fit.synds"
  return(object)
}

###-----checkinf-----------------------------------------------------------
# used in glm.synds and lm.synds and multinom.synds 

checkinf <- function(vars, formula, vs, method){
  inform <- all.vars(formula) # get variables in formula
  if ("." %in% inform) inform <- vars
  if (any(!inform %in% vars)) stop("Variable(s) in formula are not in synthetic data: ",
    paste(inform[!inform %in% vars], collapse = ", "), call. = FALSE)
  if (any(!inform %in% names(vs))) cat("\nSTERN WARNING: Variable(s) in formula are\nnot in visit sequence:",
    paste(inform[!inform %in% names(vs)], collapse = ", "),
"\n******************************************
This inference will be wrong because these\nvariables will not match synthesised data
******************************************\n\n")
  inform <- inform[inform %in% names(vs)]
  vsin <- vs[names(vs) %in% inform]
  methin <- method[names(method) %in% inform]
  methin <- methin[match(names(vsin), names(methin))] 
  blankmeths <- (1:length(methin))[methin == ""]
  if (!all(blankmeths == (1:length(blankmeths)))) { 
    cat("\nSTERN WARNING: Variables in formula with\nblank methods are not at start of visit sequence",
"\n******************************************
This inference will be wrong because these\nvariables will not match synthesised data
******************************************\nMethods in synthesis order:\n")
  print(methin)
  cat("\n")
  }
}


###-----print.fit.synds----------------------------------------------------

print.fit.synds <- function(x, msel = NULL, ...)
{
  if (!is.null(msel) & !all(msel %in% (1:x$m))) stop("Invalid synthesis number(s).", call. = FALSE)
  n <- sum(x$n); if (is.list(x$k)) k <- sum(x$k[[1]]) else k <- sum(x$k)

  if (n != k | x$m > 1) cat("Note: To get a summary of results you would expect from the original data, or for population inference use the summary function on your fit.\n") 
  
  cat("\nCall:\n")
  print(x$call)
  if (is.null(msel)) {
    cat("\nCombined coefficient estimates:\n")
    print(x$mcoefavg)
  } else {
    cat("\nCoefficient estimates for selected synthetic data set(s):\n")
    print(x$mcoef[msel,,drop = FALSE])
  }
  invisible(x)
}


###-----summary.fit.synds--------------------------------------------------

summary.fit.synds <- function(object, population.inference = FALSE, msel = NULL, 
                              incomplete = FALSE, real.varcov = NULL, ...)
{ # df.residual changed to df[2] because didn't work for lm 
  if (!class(object) == "fit.synds") stop("Object must have class fit.synds\n")
  m <- object$m
  n <- sum(object$n)                                                     
  if (is.list(object$k)) k <- sum(object$k[[1]]) else k <- sum(object$k)  
    
  coefficients <- object$mcoefavg  # mean of coefficients (over m syntheses)
  if (!is.null(real.varcov))  vars <- diag(real.varcov)
  else  vars <- object$mvaravg * k/n  # mean of variances (over m syntheses) * adjustment

## Checks and warnings for incomplete method
#---
 if (incomplete == TRUE) {
   if (population.inference == TRUE & m == 1) {
     stop("You have selected population inference using a method for incompletely synthesised data with\n m = 1 - standard errors cannot be calculated.\n", call. = FALSE)
   } else if (population.inference == TRUE & m < 5) {
     cat("Note: You have selected population inference using a method for incompletely synthesised data with m = ", m, ",\nwhich is smaller than the minimum of 5 recommended. The estimated standard errors of\nyour coefficients may be inaccurate.\n", sep = "")
   }
 }
#--- 

## Inference to Q hat
#---
 if (population.inference == FALSE) { 
   result <- cbind(coefficients,
                   sqrt(vars),
                   coefficients/sqrt(vars),
                   2*pnorm(-abs(coefficients/sqrt(vars))))
   colnames(result) <- c("xpct(Beta)", "xpct(se.Beta)", "xpct(z)", "Pr(>|xpct(z)|)")
#--- 

## Population inference to Q
#---   
 } else { 
  
  ## check that y variable is synthesised not needed
  # if (!is.matrix(object$method)) {if ( object$method[names(object$method) == as.character(formula(object)[[2]])] == "" ) cat("\nWarning: If your response variable is not synthesised, the standard errors here are probably too large.\n")}
  # else if ( object$method[1,][dimnames(object$method)[[2]] == as.character(formula(object)[[2]])] == "" ) cat("\nWarning: If your response variable is not synthesised, the standard errors here are probably too large.\n")
    
  ## incomplete method  
   if (incomplete == TRUE) {
     bm <- apply(object$mcoef, 2, var)
     result <- cbind(coefficients,
                     sqrt(bm/m + vars),
                     coefficients/sqrt(bm/m + vars),
                     2*pnorm(-abs(coefficients/sqrt(bm/m + vars))))

  ## simple synthesis   
    } else {
      if (object$proper == FALSE) Tf <- vars*(1 + n/k/m) else Tf <- vars*(1 + (n/k + 1)/m)
      result <- cbind(coefficients, 
                      sqrt(Tf), 
                      coefficients/sqrt(Tf),
                      2*pnorm(-abs(coefficients/sqrt(Tf)))) 
    }
    colnames(result) <- c("Beta.syn","se.Beta.syn","z.syn","Pr(>|z.syn|)")
  }
#---
  
 res <- list(call = object$call, proper = object$proper,
             population.inference = population.inference,
             incomplete = incomplete, 
             fitting.function = object$fitting.function,
             m = m, coefficients = result, n = n, k = k, 
             analyses = object$analyses, msel = msel)
 class(res) <- "summary.fit.synds"
 return(res)
}


###-----print.summary.fit.synds--------------------------------------------

print.summary.fit.synds <- function(x, ...) {
 
 if (!is.null(x$msel) & !all(x$msel %in% (1:x$m))) stop("Invalid synthesis number(s)", call. = FALSE)
 cat("Warning: Note that all these results depend on the synthesis model being correct.\n")  

 if (x$m == 1) {
   cat("\nFit to synthetic data set with a single synthesis.\n")
 } else {
   cat("\nFit to synthetic data set with ", x$m, " syntheses.\n",sep = "")
 }

 if (x$population.inference) {
   cat("Inference to population coefficients.\n")
 } else {
   cat("Inference to coefficients and standard errors that\nwould be obtained from the observed data.\n")
 }
   
 cat("\nCall:\n")
 print(x$call)
 cat("\nCombined estimates:\n")
 printCoefmat(x$coefficients)

 if (!is.null(x$msel)) {
   allcoef <- lapply(lapply(x$analyses[x$msel], "[[", "coefficients"), as.data.frame)
   
   estimates <- lapply(allcoef, "[", "Estimate")
   allestimates <- do.call(cbind, estimates)
   
   zvalues <- lapply(allcoef, "[", "z value")
   allzvalues <- do.call(cbind, zvalues)
   
   colnames(allestimates) <- colnames(allzvalues) <- paste0("syn=",x$msel)
   
   cat("\nEstimates for selected syntheses contributing to the combined estimates:\n")
   
   cat("\nCoefficients:\n")
   print(allestimates)
   cat("\nz values:\n")
   print(allzvalues)
   
   # for(i in x$msel) {          
   #   cat("\nsyn=",i,"\n",sep = "")
   #   print(x$analyses[[i]]$coefficients)
   # }
 }      
 invisible(x)
}


###-----print.compare.fit.synds--------------------------------------------

print.compare.fit.synds <- function(x, print.coef = x$print.coef, ...){

  cat("\nCall used to fit models to the data:\n")
  print(x$call)
  if (print.coef == TRUE) {
    cat("\nEstimates for the observed data set:\n")
    print(x$coef.obs)
    cat("\nCombined estimates for the synthetised data set(s):\n")
    print(x$coef.syn)
  }  
    
  cat("\nDifferences between results based on synthetic and observed data:\n")
    print(cbind.data.frame(x$coef.diff,x$ci.overlap))                                 
  if (x$m == 1) {
    cat("\nMeasures for one synthesis and ", x$ncoef, " coefficients", sep = "") 
  } else {
    cat("\nMeasures for ", x$m, " syntheses and ", x$ncoef, " coefficients", sep = "") 
  }   
  cat("\nMean confidence interval overlap: ", x$mean.ci.overlap)
  cat("\nMean absolute std. coef diff: ", x$mean.abs.std.diff)
  cat("\nLack-of-fit: ", x$lack.of.fit,"; p-value ", round(x$lof.pval,3), " for test that synthesis model is compatible ", sep = "")
  if (x$incomplete == FALSE) cat("\nwith a chi-squared test with ", x$ncoef, " degrees of freedom\n", sep = "")
  else cat("\nwith an F distribution with ",x$ncoef," and ",x$m - x$ncoef," degrees of freedom\n", sep = "") 

  if (!is.null(x$ci.plot)) {
    cat("\nConfidence interval plot:\n")
    print(x$ci.plot)
  }
  invisible(x)
}


###-----print.compare.synds------------------------------------------------

print.compare.synds <- function(x, ...) {

  cat("\nComparing percentages observed with synthetic\n\n")
  if (class(x$plots)[1] == "gg") {
    print(x$tables) 
    print(x$plots)
  } else {
    for (i in 1:length(x$tables)) {
      print(x$tables[[i]]) 
      print(x$plots[[i]])
      if (i < length(x$tables)) {
        cat("Press return for next plot: ")
        ans <- readline()
      }
    }
  }
 invisible(x)
}


###-----print.utility.gen--------------------------------------------------

print.utility.gen <- function(x, digits = x$digits,  
  print.zscores = x$print.zscores, zthresh = x$zthresh, 
  print.ind.results = x$print.ind.results,
  print.variable.importance = x$print.variable.importance, ...){
  
  cat("\nUtility score calculated by method: ", x$method, "\n")
  cat("\nCall:\n")
  print(x$call)
  
  if (!is.null(x$resamp.method)) {
    if (x$resamp.method == "perm") cat("\nNull utility simulated from a permutation test with ", x$nperm," replications\n", sep = "")
    else if (x$resamp.method == "pairs") cat("\nNull utility simulated from ", x$m*(x$m - 1)/2," pairs of syntheses\n", sep = "")
    
    if (!is.list(x$nnosplits)) { 
      if (x$nnosplits[1] > 0) cat(
"\n***************************************************************
Warning: null utility resamples failed to split ", x$nnosplits[1], " times from ", x$nnosplits[2],
"\n***************************************************************\n", sep = "")
    } else {
      for (ss in 1:x$m) {
        if (x$nnosplits[[ss]][1] > 0) cat("\nSynthesis ", ss, 
          " null utility resamples failed to split ", x$nnosplits[[ss]][1],
          " times from ", x$nnosplits[[ss]][2], sep = "")
      }
      cat("\n")
    }
  }
  
  if (x$m > 1) {
    cat("\nUtility score results from ", x$m, " syntheses",
        "\npMSE: ", mean(x$pMSE),
        "; Utility: ", round(mean(x$utilVal), digits),
        "; Expected value: ", round(mean(x$utilExp), digits),
        "; Ratio to expected: ", round(mean(x$utilR), digits),
        "; Standardised: ", round(mean(x$utilStd),digits), "\n", sep = "")
    
    if (print.ind.results == TRUE) {
      cat("\nIndividual utility score results from ", x$m, " syntheses\n", sep = "")
      tabres <- cbind(x$pMSE, round(x$utilVal, digits), round(x$utilExp, digits), 
        round(x$utilR, digits), round(x$utilStd, digits))
      dimnames(tabres) <- list(1:length(x$utilVal), 
        c("pMSE", "Utility","Expected","Ratio","Standardised"))
      print(tabres)
    }
    
  } else {
    cat("\nUtility score results\n",
        "pMSE: ", x$pMSE,
        "; Utility: ", round(x$utilVal, digits),
        "; Expected value: ", round(x$utilExp, digits),
        "; Ratio to expected: ", round(x$utilR, digits),
        "; Standardised: ", round(x$utilStd, digits),"\n", sep = "")
  }
  
  if (print.zscores == TRUE) {
    if (x$method == "cart") {
      cat("\nz-scores not available for CART models\n")
    } else {
      if (x$m > 1) {
        allzscores <- vector("list", x$m) 
        for (i in 1:x$m) allzscores[[i]] <- summary(x$fit[[i]])$coefficients[ ,3] 
        allnames <- unique(unlist(lapply(allzscores, names)))
        allzscores.NA <- lapply(allzscores, "[", allnames) 
        allzscores.NA.df <- do.call(cbind, allzscores.NA)
        zscores <- apply(allzscores.NA.df, 1, mean, na.rm = TRUE)  
        names(zscores) <- allnames
      } else {
        zscores <- summary(x$fit)$coefficients[ ,3]
      }
      
      if (!is.na(zthresh)) { 
        zscores <- zscores[abs(zscores) > zthresh]
        if (length(zscores) == 0) {
          cat("\nNo z-scores (or mean z-scores if m > 1) above threshold of +/-", zthresh,"\n", sep = "")
        } else {
          cat("\nz-scores (or mean z-scores if m > 1) greater than the threshold of +/- ", zthresh, "\n", sep = "")
          print(zscores)
        }  
      } else {
        cat("\nAll z-scores (or mean z-scores if m > 1)\n")
        print(zscores)
      }
    }
  }
  #browser()
  if (print.variable.importance == TRUE) {
    if (x$method != "cart" | x$tree.method != "rpart") {
      cat("\nVariable importance only available for CART models using function 'rpart'\n")
    } else {
      cat("\nRelative importance of each variable scaled to add to 100\n" )
      if (x$m == 1) {
        variable.importance <- x$fit$variable.importance
        variable.importance <- round(variable.importance/sum(variable.importance)*100, digits)
        print(variable.importance)
      } else {
        cat("(results for ", x$m, " syntheses)\n", sep = "")
        variable.importance <- vector("list", x$m)
        for (i in 1:x$m) {
          if (is.null(x$fit[[i]]$variable.importance)) x$fit[[i]]$variable.importance <- NA
          variable.importance[[i]] <- x$fit[[i]]$variable.importance
          variable.importance[[i]] <- round(variable.importance[[i]]/sum(variable.importance[[i]])*100, digits)
        }
        allnames <- unique(unlist(lapply(variable.importance, names)))
        all.vars <- lapply(variable.importance, "[", allnames) 
        all.vars.importance <- do.call(rbind, all.vars)
        colnames(all.vars.importance) <- allnames
        rownames(all.vars.importance) <- 1:x$m
        print(all.vars.importance)
      }
    }
  }
  invisible(x)
  
}


###-----print.utility.tab--------------------------------------------------

print.utility.tab <- function(x, print.tables = x$print.tables,  
  print.zdiff = x$print.zdiff, digits = x$digits, ...){

  if (print.tables == TRUE) {
    if (is.table(x$tab.obs)) {
      if (sum(x$tab.obs) != x$n) {
        cat("\nObserved adjusted to match the size of the synthetic data: \n($tab.obs)\n")
        print(round(x$tab.obs, digits))
      } else {
        cat("\nObserved: \n($tab.obs)\n")
        print(x$tab.obs)
      }  
    } else {
      #if (sum(x$tabd)/length(x$tabd)!= x$n) 
      cat("\nMean of ",x$m," observed tables ($tab.obs) adjusted to match the size of synthetic data:\n", sep = "")
      meantabd <- apply(simplify2array(x$tab.obs), c(1,2), mean)
      print(round(meantabd, digits))
    } 

    if (x$m == 1) {
      cat("\nSynthesised: \n($tab.syn)\n")
	    print(x$tab.syn) 
    } else {
      meantab <- apply(simplify2array(x$tab.syn), c(1,2), mean)
      cat("\nMean of ",x$m," synthetic tables ($tab.syn):\n", sep = "")
      print(round(meantab, digits))
    }
  }
  
  if (print.zdiff == TRUE) {
    cat("\nTable of z-scores for differences: \n($tab.zdiff)\n")
    if (x$m == 1) {
      print(round(x$tab.zdiff, digits)) 
    } else {
      meanzdiff <- apply(simplify2array(x$tab.zdiff), c(1,2), mean)
      cat("\nMean of ",x$m," z-score tables:\n", sep = "")
      print(round(as.table(meanzdiff), digits))
    }
  }
  
  if (x$m == 1) {
    cat("\nNumber of cells in each table: ", 
        x$df[1] + x$nempty[1] + 1,
        "; Number of cells contributing to utility measures: ", 
        x$df + 1,"\n", sep = "")
    cat("\nUtility score results\n")
    cat("Freeman Tukey (FT): ", round(x$UtabFT,digits), ";",
        " Ratio to degrees of freedom (df): ", round(x$ratioFT,digits), ";",
        " p-value: ", x$pvalFT, "\n", sep = "")
    cat("Voas Williamson (VW): ", round(x$UtabVW,digits), ";",
        " Ratio to degrees of freedom (df): ", round(x$ratioVW,digits), ";",
        " p-value: ", x$pvalVW, "\n", sep = "")
  } else if (x$m > 1) {
    cat("\nAverage results for ", x$m, " syntheses\n", sep = "")
    cat("\nNumber of cells in each table: ", 
        round(mean(x$df[1] + x$nempty[1] + 1), digits),
        "; Number of cells contributing to utility measures: ", 
        round(mean(x$df + 1), digits),"\n", sep = "")
    cat("\nUtility score results\n")
    cat("Freeman Tukey (FT): ", round(mean(x$UtabFT),digits), ";",
        " Ratio to degrees of freedom (df): ", round(mean(x$ratioFT),digits),"\n", sep = "")
    cat("Voas Williamson (VW): ", round(mean(x$UtabVW), digits), ";",
        " Ratio to degrees of freedom (df): ",  round(mean(x$ratioVW), digits),"\n", sep = "")
    
    cat("\nResults from individual syntheses\n")
    tab.res <- cbind.data.frame(x$df,
    round(x$UtabFT,digits), round(x$pvalFT,digits),
    round(x$UtabVW,digits), round(x$pvalVW,digits))
    colnames(tab.res) <- c("df", 
                           "FT Utility","FT p-value",
                           "VW Utility","VW p-value")
    print(tab.res)
  }

 	invisible(x)
}


###-----summary.out--------------------------------------------------------
summary.out <- function(z, digits = max(3L, getOption("digits") - 3L), ...)
{
    ncw <- function(x) {
        zz <- nchar(x, type = "w")
        if (any(na <- is.na(zz))) {
            zz[na] <- nchar(encodeString(zz[na]), "b")
        }
        zz
    }
    nv <- length(z)
    nm <- names(z)
    lw <- numeric(nv)
    nr <- if (nv)
        max(unlist(lapply(z, NROW)))
    else 0
    for (i in seq_len(nv)) {
        sms <- z[[i]]
        if (is.matrix(sms)) {
            cn <- paste(nm[i], gsub("^ +", "", colnames(sms),
                useBytes = TRUE), sep = ".")
            tmp <- format(sms)
            if (nrow(sms) < nr)
                tmp <- rbind(tmp, matrix("", nr - nrow(sms),
                  ncol(sms)))
            sms <- apply(tmp, 1L, function(x) paste(x, collapse = "  "))
            wid <- sapply(tmp[1L, ], nchar, type = "w")
            blanks <- paste(character(max(wid)), collapse = " ")
            wcn <- ncw(cn)
            pad0 <- floor((wid - wcn)/2)
            pad1 <- wid - wcn - pad0
            cn <- paste0(substring(blanks, 1L, pad0), cn, substring(blanks,
                1L, pad1))
            nm[i] <- paste(cn, collapse = "  ")
            z[[i]] <- sms
        }
        else {
            sms <- format(sms, digits = digits)
            lbs <- format(names(sms))
            sms <- paste0(lbs, ":", sms, "  ")
            lw[i] <- ncw(lbs[1L])
            length(sms) <- nr
            z[[i]] <- sms
        }
    }
    if (nv) {
        z <- unlist(z, use.names = TRUE)
        dim(z) <- c(nr, nv)
        if (anyNA(lw))
            warning("probably wrong encoding in names(.) of column ",
                paste(which(is.na(lw)), collapse = ", "))
        blanks <- paste(character(max(lw, na.rm = TRUE) + 2L),
            collapse = " ")
        pad <- floor(lw - ncw(nm)/2)
        nm <- paste0(substring(blanks, 1, pad), nm)
        dimnames(z) <- list(rep.int("", nr), nm)
    }
    else {
        z <- character()
        dim(z) <- c(nr, nv)
    }
    attr(z, "class") <- c("table")
    z
}
