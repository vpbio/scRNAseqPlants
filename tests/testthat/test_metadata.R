test_that("metadata is valid", {
  if (!requireNamespace("ExperimentHubData", quietly = TRUE))
    skip("ExperimentHubData not available")

  path <- find.package("scRNAseqPlants")
  metadata <- system.file("extdata", "metadata.csv", package = "scRNAseqPlants")

  expect_s4_class(
    ExperimentHubData::makeExperimentHubMetadata(path, metadata),
    "list"
  )
})
