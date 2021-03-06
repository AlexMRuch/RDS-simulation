library(RDS)
library(plyr)
library(rmarkdown)

args <- commandArgs(trailingOnly = TRUE)

N_RDS_SAMPLES <- 200

basePath <- args[1]
#basePath <- "simulationRuns/sim_6/"
toEstimate <- list.dirs(file.path(basePath, "data"), recursive=F, full.names=T)

bigDfFn <- file.path( basePath, "RDSanalysis.csv" )


# generate a list of all columns I'll be interested in, along with their true values!

toPlot <- NULL
newcols <- outer("testatus_", c("i","s","r","0"), FUN="paste0")
newcols <- outer( paste0(newcols,"_"), c("rdsIest","rdsIIest"), FUN="paste0")
toPlot <- c(toPlot, newcols)

newcols <- outer("blk_", c("1","0"), FUN="paste0")
newcols <- outer( paste0(newcols,"_"), c("rdsIest","rdsIIest"), FUN="paste0")
toPlot <- c(toPlot, newcols)

trPlot <- NULL
newcols <- outer("testatus_", c("i","s","r","0"), FUN="paste0")
newcols <- outer( paste0(newcols,"_"), c("true","true"), FUN="paste0")
trPlot <- c(trPlot, newcols)

newcols <- outer("blk_", c("1","0"), FUN="paste0")
newcols <- outer( paste0(newcols,"_"), c("true","true"), FUN="paste0")
trPlot <- c(trPlot, newcols)



if( file.exists(bigDfFn) ){
  bigDf <- read.csv(bigDfFn)
} else {
  bigDf <- NULL
  
  for( dr in toEstimate) {
    if( !file.exists(file.path( dr, 'RDS.full.csv' )) )
      next;
    
    d.full <- read.csv( file.path( dr, 'RDS.full.csv' ) )
    
    for( i in 0:N_RDS_SAMPLES ) {
      sampleFn <- file.path( dr, paste("RDSsample", i, "csv", sep=".") )
      print(sampleFn)
      if( !file.exists(sampleFn) ) {
        print( c('Warning... Expected file ', sampleFn, ' to exist...') )
        next;
      }
      
      d <- read.csv( sampleFn, colClasses=c("integer", "integer", "integer", "character", "character") )
      # all seeds should be given the same unique identifier
      seeds <- d[ is.na( d$recruiter ), "recruit"]
      d[ d$recruit %in% seeds, "recruit" ] <- -1
      d[ d$recruiter %in% seeds, "recruiter" ] <- -1
      d <- d[ d$recruit != -1, ]
      
      dfr <- list(i, dr)
      names(dfr) <- c("sampleNo", "pop")
      
      rds.df <- as.rds.data.frame(d, id = "recruit", network.size = "degree", population.size = NULL, max.coupons = 3, recruiter.id = "recruiter")
      cumulative.estimate(rds.df, outcome.variable = "blk")
      
      rdsEstimates <- function (attr) {
        # the names for this row
        fn <- NULL
        
        # the values for this row
        fr <- NULL
        
        # make the RDS computations
        eIte <- RDS.I.estimates(rds.df, outcome.variable = attr)
        eIIte <- RDS.II.estimates(rds.df, outcome.variable = attr)
        
        # add the estimates for this RDS sample
        fn <- c(fn, paste(attr, "_", names(eIte$estimate), "_rdsIest", sep="") )
        fn <- c(fn, paste(attr, "_", names(eIIte$estimate), "_rdsIIest", sep="") )
        
        fr <- c(fr, eIte$estimate)
        fr <- c(fr, eIIte$estimate)
        
        # add the se for this RDS sample
        fn <- c(fn, paste(attr, "_", rownames(eIte$interval), "_rdsIse", sep="") )
        fn <- c(fn, paste(attr, "_", rownames(eIIte$interval), "_rdsIIse", sep="") )
        
        fr <- c(fr, eIte$interval[,"s.e."])
        fr <- c(fr, eIIte$interval[,"s.e."])
        
        true <- prop.table(table(d.full[,attr]))
        
        fn <- c(fn, paste(attr, "_", names(true), "_true", sep="") )
        fr <- c(fr, true)
        
        names(fr) <- fn
        fr
      }
      
      dfr <- c(
        dfr,
        rdsEstimates("testatus"),
        rdsEstimates("blk")
      )
      
      dfr <- as.data.frame(dfr)
      bigDf <- rbind.fill(bigDf, dfr)
      
      #reingold.tilford.plot(rds.df)
    }
  }
  
  write.csv( bigDf, bigDfFn )
}

if(F) {
  # render summary pdfs!
  for( dr in toEstimate ) {
    d.full <- read.csv( file.path( dr, 'RDS.full.csv' ) )
    rmarkdown::render("episim/summaryStats.Rmd", params=list(
      basePath=dr
    ), output_file = file.path( "..", dr, "img", 'summaryStats.pdf'))
  }
}
  
if(T) {
  imgDir <- file.path(basePath, "img")
  dir.create( imgDir, showWarnings=F )
  
  
  dir.create( file.path(imgDir,"ests"), showWarnings=F )
  # these plots are nice...
  for(pop in unique(bigDf$pop)) {
    myData <- bigDf[bigDf$pop == pop, ] #c(toPlot, "testatus_i_true", "testatus_s_true", "testatus_0_true")
    
    for(attri in 1:length(toPlot)) {
      if( !( toPlot[attri] %in% names(myData)) ) {
        next;
      }
      attr <- toPlot[attri]
      
      png( file.path(imgDir, "ests", paste(basename(pop),".",attr,".png")) )
      
      trValue <- myData[,trPlot[attri]]
      hist(myData[,attr], main=paste(pop, attr), breaks=20)
      abline(v=trValue, col="red")
      
      dev.off()
    }
  }
}

if(F) {
  library(igraph)
  library(intergraph)
  
  n.ig <- asIgraph(n)
  
  V(n.ig)$frame.color <- "white"
  V(n.ig)$color <- "orange"
  V(n.ig)$label <- ""
  V(n.ig)$size <- 10
  E(n.ig)$arrow.mode <- 0
  
  n.sub <- induced_subgraph(graph=n.ig, vids=sample(V(n.ig), size=200))
  plot(n.sub)
}


if(F) {
  # basic attributes of prevalence
  par(mfrow = c(1,2))
  plot(mod, main = "State Prevalences")
  plot(mod, popfrac = FALSE, main = "State Sizes", sim.lines = TRUE, 
       qnts = FALSE, mean.smooth = FALSE)
  
  par(mfrow = c(1, 2))
  plot(mod, y = "num", popfrac = FALSE, main = "Population Size", ylim = c(0, 1000))
  plot(mod, y = "meanAge", main = "Mean Age", ylim = c(18, 70))
  
  par(mfrow = c(1, 2))
  plot(mod, y = "d.flow", popfrac = FALSE, mean.smooth = TRUE, qnts = 1, main = "Deaths")
  plot(mod, y = "b.flow", popfrac = FALSE, mean.smooth = TRUE, qnts = 1, main = "Births")
}

if(F) {
  # plot the network
  n <- get_network(mod, sim = 1, collapse = TRUE, at = 25)
  
  set.vertex.attribute(n, "testatus", nodesCSV[nodesCSV$t==41, "testatus"])
  
  plot(n, vertex.col="blk")
  plot(n, vertex.col="testatus", vertex.cex=.5, edge.cex=0)
}