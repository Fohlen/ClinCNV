EstimateModeSimple <- function(x, chrom="", genders=NULL) {
  if (chrom != "") {
    if (chrom %in% c("X", "Y", "chrX", "chrY")) {
      if (is.null(genders)) {
      x = x[which(x > median(x))]
      } else {
        if (chrom == "chrX") {
          x = x[which(genders == "F")]
          if (length(x) < 2) {
            x = x[which(x > median(x))]
          }
        }
        if (chrom == "chrY") {
          x = sqrt(2) * x[which(genders == "M")]
          if (length(x) < 2) {
            return(1)
          }
        }
      }
    }
  }
  if (length(x) > 50) {
    density_of_x <-  density(x, kernel="gaussian")
    mu = density_of_x$x[which.max(density_of_x$y)]
  } else if (length(x) > 30 ){
    mu = median(x)
  } else {
    mu = lehmanHodges(x)
  }
  if (mu < 0.3) {
    mu = median(x)
  }
  mu
}

    


determineSDsOfGermlineSample <- function(x) {
  return(Qn(x))
}

determineSDsOfGermlineProbe <- function(x, i) {
  if (bedFile[i,1] %in% c("chrX", "chrY")) {
    x = x[which(x > median(x))]
  }
  return(Qn(x))
}

esimtateVarianceFromSampleNoise <- function(vecOfSDsParam, numberOfRepetitions) {
  sds <- rep(0, numberOfRepetitions)
  multiplicatorForSN <- rep(0, numberOfRepetitions)
  for (j in 1:numberOfRepetitions) {
    generatedRandomSample <- rnorm(length(vecOfSDsParam), mean=0, sd=vecOfSDsParam)
    sds[j] = sd(generatedRandomSample)
    multiplicatorForSN[j] = sds[j] / Qn(generatedRandomSample)
  }
  finalSDs <- median(sds)
  return(list(median(multiplicatorForSN), vecOfSDsParam / finalSDs))
}



form_matrix_of_likeliks_one_sample <- function(i, j, k, sds, resid, vectorOfCNstates) {
  vector_of_values <- resid[,k]
  
  matrix_of_BFs <- matrix(0, nrow=(j - i + 1), ncol=length(vectorOfCNstates))
  start <- 1
  end <- j - i + 1
  
  homozygousDelSD = 0.5 / 10
  
  sdsTmp = sds
  matrix_of_BFs = sapply(1:ncol(matrix_of_BFs), function(l) {
    sds = sdsTmp
    if (vectorOfCNstates[l] < 0.5) {
      sds[which(sds < homozygousDelSD)] = homozygousDelSD
    }
    value = return_likelik((vector_of_values - vectorOfCNstates[l]) / (sds) ) / (sds) + 10^-100
    return(-2 * log(value))
  })
  return(matrix_of_BFs)
}



returnSdsForSampleAndProbe <- function(i, j) {
  sdToReturn = sdsOfSomaticSamples[j]
  return(sdToReturn * esimtatedVarianceFromSampleNoise[i] * multiplicator)
}



qcControl <- function(sam_no, toyMatrixOfLogFold, toyLocalSds, toyMultipliersDueToLog, found_CNVs, percentage) {
  copyOftoyMatrixOfLogFold <- toyMatrixOfLogFold
  pointsThatAreCNVs <- c()
  if (nrow(found_CNVs) > 0) {
    for (i in 1:nrow(found_CNVs)) {
      pointsThatAreCNVs <- c(pointsThatAreCNVs, found_CNVs[i,2]:found_CNVs[i,3])
    }
    if (length(pointsThatAreCNVs) >= nrow(copyOftoyMatrixOfLogFold) - 10) {
      return(-1)
    }
    copyOftoyMatrixOfLogFold <- copyOftoyMatrixOfLogFold[-pointsThatAreCNVs,,drop=F]
    toyLocalSds <- toyLocalSds[-pointsThatAreCNVs]
  }
  
  if (nrow(copyOftoyMatrixOfLogFold) > 0) {
    samLogFold <- copyOftoyMatrixOfLogFold[, sam_no]
    samLogFold = (samLogFold - median(samLogFold)) / toyLocalSds
    samLogFoldThreshold = quantile(samLogFold ** 2, percentage)
    samLogFold = samLogFold[which((samLogFold ** 2) < samLogFoldThreshold)]
    finalQChisq <- pchisq(sum(samLogFold ** 2), df = length(samLogFold))
    return(finalQChisq)
  } else {
    return(-1)
  }
}



plotFoundCNVs <- function(found_CNVs, toyLogFoldChange, toyBedFile, outputFolder, chrom, cn_states, toySizesOfPointsFromLocalSds, alleleFrequency, plottingOfPNGs) {
  vector_of_states <- cn_states
  cnvsToOutput <- matrix(0, nrow=0, ncol=9)
  if (nrow(found_CNVs) > 0) {
    for (s in 1:nrow(found_CNVs)) {
      CNV_name <- paste(chrom, toyBedFile[found_CNVs[s,2],2], toyBedFile[found_CNVs[s,3],3], "CN:", vector_of_states[found_CNVs[s,4]], "-2ln(loglik):", found_CNVs[s,1], 
                        ", number of regions:", found_CNVs[s,3] - found_CNVs[s,2] + 1 ,
                        ", length:", toyBedFile[found_CNVs[s,3],3] - toyBedFile[found_CNVs[s,2],2])
      CNV_name_to_write <- paste(colnames(toyLogFoldChange)[sam_no],  chrom, toyBedFile[found_CNVs[s,2],2], toyBedFile[found_CNVs[s,3],3], "CN",vector_of_states[found_CNVs[s,4]], sep="_")

      
      vectorOfGeneNames = c()
      genesThatHasToBeSeparated = unique(toyBedFile[found_CNVs[s,2]:found_CNVs[s,3],5])
      for (i in 1:length(genesThatHasToBeSeparated)) {
        if (is.character(genesThatHasToBeSeparated[i]))
        vectorOfGeneNames = c(vectorOfGeneNames, unlist(strsplit(genesThatHasToBeSeparated[i], split=",")))
      }
      vectorOfGeneNamesTrimmed = c()
      if (length(vectorOfGeneNames) > 0) {
        for (elem in vectorOfGeneNames) {
          vectorOfGeneNamesTrimmed = c(vectorOfGeneNamesTrimmed,trimws(elem) )
        }
      }
      if (length(vectorOfGeneNamesTrimmed) > 0) {
      annotationGenes <- paste(unique(vectorOfGeneNamesTrimmed), collapse=",")
      } else {
        annotationGenes = "na"
      }
      CNVtoOut <- matrix(c(chrom, toyBedFile[found_CNVs[s,2],2], toyBedFile[found_CNVs[s,3],3], 
                           vector_of_states[found_CNVs[s,4]], -1 * round(found_CNVs[s,1]), 
                           found_CNVs[s,3] - found_CNVs[s,2] + 1,
                           format((toyBedFile[found_CNVs[s,3],3] - toyBedFile[found_CNVs[s,2],2]) / 1000, nsmall=3),
                           format(round(alleleFrequency[s], digits=3), nsmall=3),
                           annotationGenes), nrow=1)
      cnvsToOutput = rbind(cnvsToOutput, CNVtoOut)
      
      length_of_repr <- 1000
      

      st <- found_CNVs[s,2]
      fn <- found_CNVs[s,3]
      
      pr = plottingOfPNGs
      if (pr) {
        plot_st <- max(1,st - length_of_repr)
        plot_fn <- min(length(toyLogFoldChange), fn + length_of_repr)
        png(filename=paste0(outputFolder, "/", paste0(CNV_name_to_write, ".png")), type = "cairo", width = 1536, height = 640)
		#bitmap(filename=paste0(outputFolder, "/", paste0(CNV_name_to_write, ".png")) ,width = 1024, height = 640, units = "px" )

        

        plot(toyLogFoldChange[plot_st:plot_fn], main=CNV_name, ylab="Copy Number", xlab=(paste("CNV within Chromosome Arm" )),
             ylim=c(0, 3), cex=toySizesOfPointsFromLocalSds[plot_st:plot_fn], yaxt='n')
        
        axis(side = 2, at = sqrt(cn_states/2), labels = cn_states)
        abline(v=c(st - plot_st, st - plot_st + fn - st + 1), col="red")
        #text(x = (st - 2 * plot_st + fn) / 2, y = (max(toyLogFoldChange[st:fn]) + 0.1), pos=ifelse(found_CNVs[s,4] > 2, 3, 1), 
        #     labels=c(paste("Genes affected:", paste(unique(bedFile[st:fn, 5]), collapse=", " ))), cex=2,
        #     family = "mono")
        #legend(x = (st - 2 * plot_st + fn) / 2, y = (max(toyLogFoldChange[st:fn]) + 0.1), 
        #       legend=c(paste("Genes affected:", paste(unique(bedFile[st:fn, 5]), collapse=", " ))), cex=2)
        
        
        abline(h=sqrt(cn_states/2),lty=2,col=colours,lwd=3)

        points((st - plot_st):(st - plot_st + fn - st) + 1, toyLogFoldChange[st:fn],col="black", pch=21,bg=colours[found_CNVs[s,4]], cex=toySizesOfPointsFromLocalSds[found_CNVs[s,2]:found_CNVs[s,3]])
        
        
        ### EACH POINTS WITH DISTANCE > 10 MB WILL BE SEPARATED BY VERTICAL LINE
        distanceBetweenPoints = 10 ** 6
        for (i in 2:nrow(toyBedFile)) {
          if (toyBedFile[i,2] - toyBedFile[i - 1,2] > distanceBetweenPoints) {
            abline(v = i - 0.5 - plot_st, lty=2, col="grey")
          }
        }
        
        minimumDist <- min(sqrt(cn_states/2) - max(toyLogFoldChange[max(st - 50, plot_st):min(fn + 50, plot_fn)]))
        closestLine <- which(sqrt(cn_states/2) - max(toyLogFoldChange[max(st - 50, plot_st):min(fn + 50, plot_fn)]) == minimumDist)
        text(x = (st - 2 * plot_st + fn) / 2, y = (sqrt(cn_states/2)[closestLine] + 0.1), pos=3, 
             labels=c(paste("Genes affected:", paste(unique(bedFile[st:fn, 5]), collapse=", " ))), cex=1.5,
             family = "mono")
        dev.off()
      }

    }
  }
  return(cnvsToOutput)
}




Determine.gender <- function(normalized.coverage.corrected.gc, probes) {
  set.seed(100)
  if (length(which(probes[,1] == "chrX")) > 100 & length(which(probes[,1] == "chrY")) > 10) {
    matrix_of_values <- cbind(apply(normalized.coverage.corrected.gc[which(probes[,1] == "chrY"),], 2, EstimateModeSimple), apply(normalized.coverage.corrected.gc[which(probes[,1] == "chrX"),], 2, EstimateModeSimple))
    clKmeans <- NULL
    clKmeans <- tryCatch({kmeans(matrix_of_values, centers=matrix(c(0,1,sqrt(1/2), sqrt(1/2)), nrow=2))}, 
                   error = function(e) {
                     NULL
                   })
    if (!is.null(clKmeans)) {
      clusters <- clKmeans$cluster
      clusters[clusters == 1] <- "F"
      clusters[clusters == 2] <- "M"
      png(filename=paste0(opt$out, paste0("/genders.png")), width=800, height=800)
      plot(matrix_of_values, col = clKmeans$cluster, xlab="Y Chromsome", ylab="X Chromosome", pch=19, cex=2)
      points(clKmeans$centers, col = 1:2, pch = 8, cex = 10)
      dev.off()
    } else {
      clusters <- rep(2, nrow(matrix_of_values))
      clusters[which(matrix_of_values[,2] < 0.25)] = 1
      clusters[clusters == 1] <- "F"
      clusters[clusters == 2] <- "M"
    }
  } else {
    clusters = rep("M", ncol(normalized.coverage.corrected.gc))
  }
  
  return(clusters)
}







FindRobustMeanAndStandardDeviation <- function(x, genders, chrom, modeEstimated = NA) {
  genders = genders[which(x > 0.1)]
  x = x[which(x > 0.1)]
  if (length(x) < 50) {
    if (chrom != "") {
      if (chrom %in% c("X", "Y", "chrX", "chrY")) {
        if (is.null(genders)) {
          x = x[which(x > median(x))]
        } else {
          if (chrom == "chrX") {
            if (length(which(genders == "F")) <= 5) {
              x = x[which(genders == "M")]
              x = sqrt(2) * x
            } else {
              x = x[which(genders == "F")]
            }
            if (length(x) <= 5) {
              return(matrix(c(1, 0.5, "sd"), nrow=1))
            }
          }
          if (chrom == "chrY") {
            if (length(which(genders == "M")) <= 5) {
              return(matrix(c(sqrt(1/2), 0.5, "sd"), nrow=1))
            } else {
              x = x[which(genders == "M")]
            }
          }
        }
      }
    }

    if (length(x) > 30 ){
      mu = median(x)
    } else {
      mu = lehmanHodges(x)
    }
    if (mu < 0.3) {
      mu = median(x)
    }
    return(matrix(c(mu, Qn(x), "Qn"), nrow=1))
  }

  if (chrom == "chrX") {
    if (length(which(genders == "F")) <= 5) {
      x = x[which(genders == "M")]
      x = sqrt(2) * x
    } else {
      x = x[which(genders == "F")]
    }
  }
  if (chrom == "chrY") {
    
    if (length(which(genders == "M")) <= 5) {
      return(matrix(c(sqrt(1/2), 0.5, "sd"), nrow=1))
    } else {
      x = x[which(genders == "M")] * sqrt(2)
    }
  }
  

  forMeanX = x
  return(matrix(c(median(forMeanX), Qn(forMeanX), "Qn"), nrow=1))
  
  ### THEN IT MAY BE CHANGED
  if (length(forMeanX) < 10) {
    return(matrix(c(median(forMeanX), Qn(forMeanX), "Qn"), nrow=1))
  }
  if (length(x) < 100) {
    forMeanX = apply(combn(x, 2), 2, mean)
    density_of_x <-  density(forMeanX, bw="SJ", kernel="gaussian")
  } else {
    density_of_x = density(forMeanX, bw=bandwidth, kernel="gaussian")
  }
  if (is.na(modeEstimated)) {
    mu = density_of_x$x[which.max(density_of_x$y)]
  } else {
    mu = modeEstimated
  }
    if (length(x) < 100) {
      density_of_x <-  density(x, bw=bandwidth, kernel="gaussian")
    }

  closest_to_mu <- which.min(abs(density_of_x$x - mu))
  which_are_bigger <- which(density_of_x$y > density_of_x$y[closest_to_mu])
  density_of_x <- as.data.frame(cbind(density_of_x$x, density_of_x$y))
  colnames(density_of_x) <- c("x","y")
  density_of_x[which_are_bigger,] <- density_of_x$y[closest_to_mu]
  EF = max(density_of_x$y)
  
  lower_bound = min(density_of_x$x)
  lower_bound_differs = F
  bounded_on_lower_copy_nuber = which(density_of_x$x < sqrt(mu ** 2 - 1/8))
  if (length(bounded_on_lower_copy_nuber) > 0) {
    start_to_the_left <- max(bounded_on_lower_copy_nuber)
    
    previous_value = density_of_x$y[start_to_the_left]
    for (i in seq(from = start_to_the_left, to=1, by=-1)) {
      AB =  density_of_x$y[i]
      if ((AB > previous_value + 10**-10) | AB < 10**-10) {
        lower_bound = density_of_x$x[i]
        lower_bound_differs = T
        break
      } else {
        previous_value = AB
      }
    }
  } else {
    lower_bound = sqrt(mu ** 2 + 1/8)
    lower_bound_differs = T
  }
  
  upper_bound = max(density_of_x$x)
  upper_bound_differs = F
  bounded_on_higher_copy_nuber = which(density_of_x$x > sqrt(mu ** 2 + 1/16))
  if (length(bounded_on_higher_copy_nuber) > 0) {
    start_to_the_right <- min(bounded_on_higher_copy_nuber)
    previous_value = density_of_x$y[start_to_the_right]
    for (i in seq(from = start_to_the_right, to=length(density_of_x$x), by=1)) {
      AB =  density_of_x$y[i]
      if ((AB > previous_value + 10**-10 | AB < 10**-10)) {
        upper_bound = density_of_x$x[i]
        upper_bound_differs = T
        break
      } else {
        previous_value = AB
      }
    }
  } else {
    upper_bound = sqrt(mu ** 2 + 1/16)
    upper_bound_differs = T
  }
  
  if (upper_bound_differs & lower_bound_differs) {
    dtnorm0 <- function(X, mean, sd, log = TRUE) {msm::dtnorm(X, mean, sd, lower=lower_bound, upper=upper_bound,
                                                         log=T)}
  } else if (!upper_bound_differs & !lower_bound_differs) {
    return(matrix(c(median(x), Qn(x), "Qn"), nrow=1))
  } else if (upper_bound_differs) {
    dtnorm0 <- function(X, mean, sd, log = FALSE) {msm::dtnorm(X, mean, sd, lower = -10**10, upper=upper_bound,
                                                          log=T)}
  } else {
    dtnorm0 <- function(X, mean, sd, log = FALSE) {msm::dtnorm(X, mean, sd, lower=lower_bound, upper=10**10,
                                                          log=T)}
  }
  QnX <- Qn(x)
  data = x[which(x >= lower_bound & x <= upper_bound)]
  if (is.na(modeEstimated)) {
    
    result <- tryCatch({nres=fitdistr(data, dtnorm0, start=list(mean=mean(data), sd=sd(data))); (nres$estimate)}
                       , error = function(e) {return(matrix(c(mu, QnX, "Qn"), nrow=1))})
  } else {
    result <- tryCatch({nres=fitdistr(data, dtnorm0, fix.arg=list(mean=modeEstimated), start=list(mean=modeEstimated, sd=sd(data))); (nres$estimate)}
                       , error = function(e) {return(matrix(c(mu, QnX, "Qn"), nrow=1))})
  }
  if ((as.numeric(result[1]) / mu) > 1.1 | (as.numeric(result[1]) / as.numeric(mu)) < 0.9 | is.na(result[2])) {
    return(matrix(c(mu, QnX, "Qn"), nrow=1))
  }
  # Sometimes we miss one cluster and that's cause to increase of standard deviation
  result[2] = min(QnX, result[2], sd(x))
  if (result[2] == QnX) {
    result = matrix(c(result[1], result[2], "Qn"), nrow=1)
  } else {
    result = matrix(c(result[1], result[2], "sd"), nrow=1)
  }
  result
}








returnClustering <- function(minNumOfElemsInCluster) {
  minNumOfElemsInCluster = as.numeric(minNumOfElemsInCluster)
  set.seed(100)
  clustering = rep(0, ncol(normal))

  numOfElementsInCluster = (minNumOfElemsInCluster)
  outliersFromClustering = rep(FALSE, ncol(normal))

  coverageForClustering = sqrt(normal[which(!bedFile[,1] %in% c("chrX","chrY")),])
  sdsOfRegions <- apply(coverageForClustering, 1, mad)
  potentiallyPolymorphicRegions <- which(sdsOfRegions > quantile(sdsOfRegions, 0.9) | sdsOfRegions == 0)
  
  if (ncol(normal) < 3 * minNumOfElemsInCluster) {
    print(paste("You ask to clusterise intro clusters of size", minNumOfElemsInCluster, "but size of the cohort is", ncol(normal), "which is not enough. We continue without clustering."))
    fit <- cmdscale(dist(t(sqrt(normal[-union(potentiallyPolymorphicRegions, which(bedFile[,1] %in% c("chrX","chrY"))),]))),eig=TRUE, k=2) # k is the number of dim
    x <- fit$points[,1]
    y <- fit$points[,2]
    setwd(opt$out)
    png(filename="clusteringSolution.png", width=2048, height=2048)
    plot(x, y, xlab="Coordinate 1", ylab="Coordinate 2", 
         main="Metric MDS", type="n")
    text(x, y, labels = row.names(normal), cex=.7, col=clustering + 1)
    dev.off()
    return(list(clustering, outliersFromClustering))
  }
  
  coverageForClustering = (coverageForClustering[-potentiallyPolymorphicRegions,])
  
  if (!is.null(opt$triosFile)) {
    samplesActuallyPlayingRole = c()
    for (trioRow in 1:nrow(trios)) {
      child_number <- which(colnames(coverageForClustering) == trios[trioRow, 1])
      mother_number  <- which(colnames(coverageForClustering) == trios[trioRow, 2])
      father_number  <- which(colnames(coverageForClustering) == trios[trioRow, 3])
      
      sample_name = paste(trios[trioRow,], collapse="-")
      
      if (length(child_number) == 0 | length(father_number) == 0 | length(mother_number) == 0) {
        next()
      } else {
        samplesActuallyPlayingRole = c(samplesActuallyPlayingRole, c(child_number, mother_number, father_number))
        coverageToReplace = apply(coverageForClustering[,c(child_number, mother_number, father_number)], 1, median)
        coverageForClustering[,child_number] = coverageToReplace
        coverageForClustering[,mother_number] = coverageToReplace
        coverageForClustering[,father_number] = coverageToReplace
      }
    }
    n = 3
  } else {
    n = 3
  }

  coverageForClustering = (apply(coverageForClustering, 2, function(x) tapply(x, ceiling(seq_along(x) / n), median)))
  
  corMatrix <- cor(coverageForClustering)
  
  distMatrix <- sqrt(1 - corMatrix)
  hc <- hclust(as.dist(distMatrix), method="ward.D")
  
  numOfClusters = 1
  for (numOfClusters in 2:100) {
    memb <- cutree(hc, k=numOfClusters)
    numOfObservationsInClusters <- table(memb)
    if (sum(numOfObservationsInClusters[numOfObservationsInClusters >= numOfElementsInCluster]) < 0.8 * sum(numOfObservationsInClusters)) {
      break
    }
  }
  

  memb <- cutree(hc, k=numOfClusters - 1)
  numOfObservationsInClusters <- table(memb)
  clustering = memb
  
  significantClusters = which(numOfObservationsInClusters >= numOfElementsInCluster)
  
  outliersFromClustering[which(!clustering %in% significantClusters)] = TRUE
  
  for (i in 1:length(numOfObservationsInClusters)) {
    if (numOfObservationsInClusters[i] < numOfElementsInCluster) {
      for (elem in which(clustering == i)) {
        minDist = 10**1000
        closestCluster = significantClusters[1]
        for (signCluster in significantClusters) {
          distanceToSignCluster = mean(distMatrix[which(memb == signCluster),elem])
          if (distanceToSignCluster < minDist) {
            minDist = distanceToSignCluster
            closestCluster = signCluster
          }
        }
        clustering[elem] = closestCluster
      }
    }
  }
  if (!is.null(opt$triosFile)) {
    clustering[-samplesActuallyPlayingRole] = -1
  }
  
  fit <- cmdscale(dist(t(sqrt(normal[-union(potentiallyPolymorphicRegions, which(bedFile[,1] %in% c("chrX","chrY"))),]))),eig=TRUE, k=2) # k is the number of dim

  # plot solution 
  x <- fit$points[,1]
  y <- fit$points[,2]
  setwd(opt$out)
  png(filename="clusteringSolution.png", width=2048, height=2048)
  plot(x, y, xlab="Coordinate 1", ylab="Coordinate 2", 
       main="Metric MDS", type="n")
  text(x, y, labels = row.names(distMatrix), cex=.7, col=clustering + 1)
  dev.off()
  setwd(opt$folderWithScript)
  
  return(list(clustering, outliersFromClustering))
}


likelihoodOfTwoVariables <- function(var1, var2, covariance, mean1, mean2, x1, x2, regularization=10) {
  matrixOfCov = matrix(c(var1, covariance, covariance, var2), nrow=2)
  det = var1 * var2 - covariance ** 2
  if (det <= 0) {
    return("NA")
  }
  inverseMatrixOfCov = 1 / det * matrix(c(var2, -covariance, -covariance, var1), nrow=2)
  sd1 = sqrt(var1)
  sd2 = sqrt(var2)
  x1 = max(min(mean1 + regularization * sd1, x1), mean1 - regularization * sd1)
  x2 = max(min(mean2 + regularization * sd2, x2), mean2 - regularization * sd2)
  product = (cbind(x1 - mean1, x2 - mean2) %*% inverseMatrixOfCov) %*% rbind(x1 - mean1, x2 - mean2)
  answer = -0.5 * (log(det) + (product) + 2 * log(2 * pi))
  return(answer)
}




returnTreeForCorrelation <- function(coverage.normalised.local, sdsOfGermlineSamples, sdsOfProbes, bedFileFilteredTmp) {
  coverageNormalisedBySds = sweep(coverage.normalised.local - 1, 2, sdsOfGermlineSamples, FUN="/")
  covariancesClose = rep(0, nrow(coverage.normalised.local))
  distnacesClose = rep(-1, nrow(coverage.normalised.local))
  sumOfLengths = rep(-1, nrow(coverage.normalised.local))
  minLength = rep(-1, nrow(coverage.normalised.local))
  maxLength = rep(-1, nrow(coverage.normalised.local))
  
  for (i in 2:nrow(coverageNormalisedBySds)) {
    if (bedFileFilteredTmp[i,1] %in% c("chrX","chrY")) next
    if (bedFileFilteredTmp[i,1] == bedFileFilteredTmp[i-1,1]) {
      covariancesClose[i - 1] = correlationMatrixForPairedLikelik(coverageNormalisedBySds[(i-1),], coverageNormalisedBySds[i,], sdsOfProbes[i-1], sdsOfProbes[i])[1,2]
      distnacesClose[i - 1] = bedFileFilteredTmp[i,2] - bedFileFilteredTmp[i-1,3] + 1
      sumOfLengths[i-1] = bedFileFilteredTmp[i,3] - bedFileFilteredTmp[i,2] + bedFileFilteredTmp[i - 1,3] - bedFileFilteredTmp[i-1,2]
      minLength[i-1] = min(bedFileFilteredTmp[i,3] - bedFileFilteredTmp[i,2], bedFileFilteredTmp[i - 1,3] - bedFileFilteredTmp[i-1,2])
      maxLength[i-1] = max(bedFileFilteredTmp[i,3] - bedFileFilteredTmp[i,2], bedFileFilteredTmp[i - 1,3] - bedFileFilteredTmp[i-1,2])
    }
  }
  
  trainingDataset <- as.data.frame(cbind(covariancesClose, distnacesClose, sumOfLengths, minLength, maxLength))
  if (length(which(distnacesClose < 0)) > 0)
  trainingDataset = trainingDataset[-which(distnacesClose < 0 | distnacesClose > 9500),]
  if (nrow(trainingDataset) > 100) {
  fit <- ctree(covariancesClose ~ log2((distnacesClose)) + (sumOfLengths) + minLength + maxLength, data=trainingDataset, control=ctree_control(mincriterion = 0.99))
  png(filename="treeOnCorrelationOfCoverage.png", width=4000, height=1800)
  plot(fit)
  dev.off()
  } else {
    return("NA")
  }
  
  
  return(fit)
}


form_matrix_of_likeliks_one_sample_with_cov <- function(i, j, k, sds, resid, cn_states, covarianceTree, currentBedFile, threshold_local) {
  distancesToPredict = (currentBedFile[2:nrow(currentBedFile),2] - currentBedFile[1:(nrow(currentBedFile) - 1),3] + 1)
  distancesToPredict[which(is.na(distancesToPredict) | distancesToPredict <= 0)] = 10**6
  lengthsLeft = as.numeric(currentBedFile[1:(nrow(currentBedFile) - 1),3] - currentBedFile[1:(nrow(currentBedFile) - 1),2])
  lengthsRight = as.numeric(currentBedFile[2:nrow(currentBedFile),3] - currentBedFile[2:nrow(currentBedFile),2])
  sumLengths <- lengthsLeft + lengthsRight
  maxLengths <- apply(rbind(lengthsLeft, lengthsRight), 2, max)
  minLengths <- apply(rbind(lengthsLeft, lengthsRight), 2, min)
  
  datasetToPredice <- as.data.frame(cbind(distancesToPredict, sumLengths, minLengths, maxLengths))
  colnames(datasetToPredice) <- c("distnacesClose", "sumOfLengths", "minLength", "maxLength")
  
  
  vector_of_values <- resid[,k]
  
  vector_of_states <- cn_states
  matrix_of_BFs <- matrix(0, nrow=(j - i + 1), ncol=length(vector_of_states))
  start <- 1
  end <- j - i + 1
  
  homozygousDelSD = 0.5 / 10
  
  sdsTmp = sds
  matrix_of_BFs = sapply(1:ncol(matrix_of_BFs), function(l) {
    sds = sdsTmp
    if (vectorOfCNstates[l] < 0.5) {
      sds[which(sds < homozygousDelSD)] = homozygousDelSD
    }
    value = return_likelik((vector_of_values - vector_of_states[l]) / (sds) ) / (sds) + 10^-100
    
    return(-2 * log(value))
  })
  
  covariancesForWholeDataset <- Predict(covarianceTree, datasetToPredice)
  smallDistances = which(covariancesForWholeDataset > 0.1 & distancesToPredict < 9500)
  if (length(smallDistances) > 0) {
    distancesToPredict = distancesToPredict[smallDistances]
    covariances <- covariancesForWholeDataset[smallDistances]
    
    coordsOfIntermediateValues <- sapply(1:length(smallDistances), function(l) {return(
      c(currentBedFile[smallDistances[l],1], round((currentBedFile[smallDistances[l],3] + currentBedFile[smallDistances[l] + 1,2])/ 2),
        round((currentBedFile[smallDistances[l],3] + currentBedFile[smallDistances[l] + 1,2])/ 2)))})
    coordsOfIntermediateValues = matrix(coordsOfIntermediateValues, ncol=3, byrow=T)
    colnames(coordsOfIntermediateValues) <- colnames(currentBedFile)[1:3]
    likeliksOfIntermediateValues <- sapply(1:length(smallDistances), function(l) {return(
      -2 * sapply(1:length(cn_states), function(m) {
        likelihoodOfTwoVariables(sds[smallDistances[l]]**2, sds[smallDistances[l] + 1]**2,
                                 covariances[l] * sds[smallDistances[l]] * sds[smallDistances[l] + 1] * ifelse(vector_of_states[m] < 0.1, 0, 1),
                                 vector_of_states[m], vector_of_states[m],
                                 vector_of_values[smallDistances[l]], vector_of_values[smallDistances[l] + 1]
        ) } ) - (matrix_of_BFs[smallDistances[l],] + matrix_of_BFs[smallDistances[l] + 1,])
    )})
    likeliksOfIntermediateValues = matrix(likeliksOfIntermediateValues, ncol=length(cn_states), byrow=T)
    likeliksOfIntermediateValues[which(likeliksOfIntermediateValues < -threshold + 1)] = -threshold + 1
    
    # TIME TO MERGE TO MATRICES OF LIKELIHOODS
    orderOfBedFile = order(coordsOfIntermediateValues[,1], as.numeric(coordsOfIntermediateValues[,2]), as.numeric(coordsOfIntermediateValues[,3]))
    likeliksOfIntermediateValues = likeliksOfIntermediateValues[orderOfBedFile,,drop=F]
    coordsOfIntermediateValues = coordsOfIntermediateValues[orderOfBedFile,,drop=F]
  } else {
    return(NULL)
    commonBedFile = matrix(0, nrow=0,ncol=3)
  }
  
  return(list(likeliksOfIntermediateValues,coordsOfIntermediateValues))
}


remapVariants <- function(found_CNVs, toyBedFileAfterCovariance, toyBedFile) {
  found_CNVs_local = found_CNVs
  for (k in 1:nrow(found_CNVs_local)) {
    start = as.numeric(toyBedFile[found_CNVs_local[k,2],2])
    end = as.numeric(toyBedFile[found_CNVs_local[k,3],3])
    newStart = min(which(as.numeric(toyBedFileAfterCovariance[,3]) > start))
    newEnd = max(which(as.numeric(toyBedFileAfterCovariance[,2]) < end))
    found_CNVs_local[k,2] = newStart
    found_CNVs_local[k,3] = newEnd
  }
  return(found_CNVs_local)
}

calculateLocationAndScale <- function(bedFile, coverage, genderOfSamples, autosomes) {
  whichSamplesUsed = 1:ncol(coverage)
  mediansResult = c()
  # WE ASSUME THERE ARE ENOUGH SAMPLES OF BOTH GENDERS
  for (chrom in unique(bedFile[,1])) {
    whichSamplesUsed = 1:ncol(coverage)
    print(chrom)
    coveragesToDealWith = coverage[which(bedFile[,1] == chrom),]
    if (chrom == "chrX") {
      if (length(which(genderOfSamples == "F")) > 0.5 * length(which(genderOfSamples == "M"))) {
        whichSamplesUsed = which(genderOfSamples == "F")
      } else {
        whichSamplesUsed = which(genderOfSamples == "M")
      }
    } else if (chrom == "chrY") {
      if (length(which(genderOfSamples == "M")) <= 2) {
        whichSamplesUsed = which(genderOfSamples == "F")
        medians = rep(1, nrow(coveragesToDealWithStandardized))
        next
      }
      whichSamplesUsed = which(genderOfSamples == "M")
    }
    medians <- parApply(cl=cl,coveragesToDealWith[,whichSamplesUsed], 1, median)
    if (chrom == "chrX" & length(which(genderOfSamples == "F")) <= 0.5 * length(which(genderOfSamples == "M"))) {
      medians = sqrt(2) * medians
    }
    if (chrom == "chrY" & length(which(genderOfSamples == "M")) > 2) {
      medians = sqrt(2) * medians
    }
    mediansResult = c(mediansResult, medians) 
  }
  
  coverage.normalised = sweep(coverage, 1, mediansResult, FUN="/") - 1
  sdsOfGermlineSamplesTmp = apply(coverage.normalised[autosomes,], 2, Qn)
  sdsResults = c()
  for (chrom in unique(bedFile[,1])) {
    whichSamplesUsed = 1:ncol(coverage)
    coveragesToDealWith = coverage.normalised[which(bedFile[,1] == chrom),]
    if (chrom == "chrX") {
      if (length(which(genderOfSamples == "F")) > 0.5 * length(which(genderOfSamples == "M"))) {
        whichSamplesUsed = which(genderOfSamples == "F")
      } else {
        whichSamplesUsed = which(genderOfSamples == "M")
      }
    } else if (chrom == "chrY") {
      if (length(which(genderOfSamples == "M")) <= 2) {
        whichSamplesUsed = which(genderOfSamples == "F")
        QNs = rep(1000, nrow(coveragesToDealWithStandardized))
        medians = rep(1, nrow(coveragesToDealWithStandardized))
        next
      }
      whichSamplesUsed = which(genderOfSamples == "M")
    }
    
    coveragesToDealWithStandardized = coveragesToDealWith[,whichSamplesUsed]
    coveragesToDealWithStandardized <- sweep(coveragesToDealWithStandardized, 2, sdsOfGermlineSamplesTmp[whichSamplesUsed], FUN="/")
    
    QNs <- parApply(cl=cl, coveragesToDealWithStandardized, 1, Qn)
    if (chrom == "chrX") {
      medianOfSdsForAllProbes = median(sdsResults[autosomes])
      medianOfSdsForX = median(QNs)
      QNs = QNs / (medianOfSdsForX / medianOfSdsForAllProbes)
    }
    if (chrom == "chrY") {
      medianOfSdsForAllProbes = median(sdsResults[autosomes])
      medianOfSdsForX = median(QNs)
      QNs = QNs / (medianOfSdsForX / medianOfSdsForAllProbes)
    }
    sdsResults <- c(sdsResults, QNs)
  }
  return(list(coverage.normalised + 1, cbind(mediansResult, sdsResults), sdsOfGermlineSamplesTmp))
}
