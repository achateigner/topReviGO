#' @title Chain topGO and REViGO analyses to produce treemaps
#'
#' @description This package takes a list of genes, a map file with the
#' correspondance between gene name and GO annotation and a prefix for the
#' output. It will then do a topGO analysis and send the results to the
#' REViGO (http://revigo.irb.hr/) website, to summarize the list of GO and
#' produce a treemap.
#'
#' @details The goal is from a list of genes and the corresponding GO map, to
#' be able to produce an enriched list of GO annotations and a treemap to
#' easily visualize. By default, the biological process is outputted, but
#' it can also be the Cellular Component or the Molecular Function. One can use
#' a installed db or a map file.
#' @param geneList The gene list must be a csv file without column name, each
#' line consisting of the gene name and a 1 or 0, separated by a ",". The 1 or
#' 0 corresponds to the fact that the gene is respectively selected or not.
#' What I mean by that is that the gene has previously been recognized by the
#' user as interesting, like belonging to a cluster, or selected by any other
#' way. It corresponds to the "Predefined list of interesting genes" from the
#' topGO vignette
#' (http://www.bioconductor.org/packages/release/bioc/vignettes/topGO/inst/doc/topGO.pdf).
#' If you don't have a predefined list, please do the previous steps of the
#' topGO vignette (before 4.4).
#' @param prefix A prefix for the outputs.
#' @param mapFile A file containing the correspondance between the gene name and
#' a GO name, 1 per line, in the format :
#' GeneName<tabulation>GOName
#' It can also be a Db name, thus one needs to change the option mapOrDb.
#' @param ontology "BP", "CC" or "MF" for Biological Process, Cellular Component
#' or Molecular Function, this is the GO categories outputted by REViGO.
#' @param mapOrDb map if a map file is used, db if a database name is provided.
#' @return A csv file containing the enriched GO terms and a treemap pdf file
#' containing the image.
#' @import topGO
#' @examples
#' library(hgu133a.db)
#' selGenes <- sample(ls(hgu133aGO), 50)
#' allGenes <-  factor(as.integer(ls(hgu133aGO) %in% selGenes))
#' names(allGenes) <- ls(hgu133aGO)
#' topReviGO(allGenes, "toto", "hgu133a", mapOrDb = "db")
#' @export
topReviGO <- function(geneList, prefix, mapFile, ontology = "BP",
                      mapOrDb = "map"){
  # Check that the geneList and prefix are provided
  if (missing(geneList) | missing(prefix) | missing(mapFile)){
    stop("geneList, prefix or mapFile is missing")
  }
  if (mapOrDb == "map"){
    # Loading the Potri map
    geneID2GO <- topGO::readMappings(file=mapFile)

    # Creation of the GOdata object
    GOdata <- methods::new("topGOdata", ontology = ontology, allGenes = geneList,
                  annot = topGO::annFUN.gene2GO, gene2GO = geneID2GO)
  } else if (mapOrDb == "db"){
    # Loading the db
    affyLib <- paste(mapFile, "db", sep = ".")
    library(package = affyLib, character.only = TRUE)

    # Creation of the GOdata object
    GOdata <- methods::new("topGOdata", ontology = ontology, allGenes = geneList,
                  annot = topGO::annFUN.db, affyLib = affyLib)

  }  else {stop('mapFile option must be "map" or "db"')}
  # Calculation of the Fisher test weightCount
  test.stat <- methods::new("weightCount", testStatistic = topGO::GOFisherTest,
                   name = "Fisher test", sigRatio = "ratio")
  resultWeight <- topGO::getSigGroups(GOdata, test.stat)

  ## Showing test stats
  topGO::geneData(resultWeight)

  # Creation of the allRes object
  allRes <- topGO::GenTable(GOdata, weightFisher = resultWeight,
                     orderBy = "weightFisher", ranksOf = "weightFisher",
                     topNodes = length(topGO::score(resultWeight)))
  allResInf1 <- allRes[allRes$weightFisher < 1,]

  # Localization of the revigoDownload.py script
  revigoDownloadLocation <- paste(system.file(package="topReviGO"),
                                  "revigoDownload.py",
                                  sep="/")
  # separator <- if (.Platform$OS.type == "windows") ";" else ":"
  # paths <- unlist(strsplit(Sys.getenv("PATH"), separator))
  # whereRD <- sapply(paths,
  #                   function(x) file.exists(paste0(x, "/revigoDownload.py")))
  # revigoDownloadLocation <- paste0(paths[whereRD], "/revigoDownload.py")
  # Incorporation of the revigoDownload.py script
  aRevigorer = "aRevigorer.txt"
  utils::write.table(allResInf1[,c("GO.ID", "weightFisher")], file=aRevigorer,
              quote=F, row.names=F, col.names=F)
  system(command = paste0("python ", revigoDownloadLocation, " -tsap ",
                          prefix, " ", aRevigorer))
  file.remove(aRevigorer)
  revigo.data <- utils::read.csv(paste0(prefix, "_treemap.csv"), skip = 4)
  revigo.data$abslog10pvalue <- abs(as.numeric(as.character(
    revigo.data$log10pvalue)))
  revigo.data$freqInDbPercent <- as.numeric(gsub("%", "",
                                                 revigo.data$frequencyInDb))
  treemap::treemap(revigo.data, index = c("representative","description"),
          vSize = "abslog10pvalue", type = "categorical",
          vColor = "representative",
          title = paste0("REVIGO Gene Ontology treemap - ", prefix,
                         " - n=", sum(as.integer(geneList)-1)),
          inflate.labels = TRUE, lowerbound.cex.labels = 0,
          bg.labels = "#CCCCCCAA", position.legend = "none")
  grDevices::pdf(file=paste0(prefix, "_treemap.pdf"))
  treemap::treemap(revigo.data, index = c("representative","description"),
          vSize = "abslog10pvalue", type = "categorical",
          vColor = "representative",
          title = paste0("REVIGO Gene Ontology treemap - ", prefix,
                         " - n=", sum(as.integer(geneList)-1)),
          inflate.labels = TRUE, lowerbound.cex.labels = 0,
          bg.labels = "#CCCCCCAA", position.legend = "none")
  grDevices::dev.off()
}

#' csvFilePreparationForTopReviGo
#' @param csvFile The csv file containing the genes, that has to be prepared.
#' @return The genes list
#' @export
csvFilePreparationForTopReviGo <- function(csvFile){
  tmpList <- utils::read.csv(csvFile, header=F, row.names=1)
  geneList <- as.factor(tmpList$V2)
  names(geneList) <- rownames(tmpList)
  return(geneList)
}
