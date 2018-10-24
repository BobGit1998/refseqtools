import "FilterDomainTasks.wdl" as Tasks

workflow FilterDomainFastas {
	String domainInputDir
	String outputDir
	String filterScriptPath
	String refseqJson
	String taxDbPath
	Array[String]? includeAccPrefixes
	Array[String]+? includeTaxa
	Array[String]+? excludeTaxa
	Array[String]? excludeAccPrefixes
	File? includeAccFile
	File? excludeAccFile
	String dustmaskerExe
	
	call Tasks.MakeScatterList as RawFastas {
		input:
			dirName = domainInputDir,
			pattern = "*fna.gz"
	}

	scatter (fastaFile in RawFastas.fastaFiles) {
		call Tasks.FilterFasta {
			input:
			    scriptPath = filterScriptPath,
			    refseqJson = refseqJson,
			    taxDbPath = taxDbPath,
				fastaIn = fastaFile,
				fastaOutPath = outputDir + '/' +
				               sub(basename(fastaFile), "genomic", "filtered_genomic"),
				includeAccPrefixes = includeAccPrefixes,
				excludeAccPrefixes = excludeAccPrefixes,
				includeTaxa = includeTaxa,
				excludeTaxa = excludeTaxa,
				includeAccFile = includeAccFile,
				excludeAccFile = excludeAccFile
		}
	}

	call Tasks.WriteFilterStats {
		input:
			stats = FilterFasta.stats,
			tsvFilePath = outputDir + "/filtering.tsv"
	}

	# This is to make sure fasta files are first filtered
	# Changing the filter_fasta.py to enable better handling of the output
	# should make this redundant
	if (size(WriteFilterStats.tsvFile) > 0) {
		call Tasks.MakeScatterList as FilteredFastas {
			input:
				dirName = outputDir,
				pattern = "*filtered_genomic.fna.gz"
		}
	} 

	# Make an array of all the existing filtered files
	Array[File] filteredFastas = flatten(select_all([FilteredFastas.fastaFiles]))

	# Dustmask the files if at least one file was created/kept after filtering
	if ( length(filteredFastas) > 0 ) {
		scatter (filteredFna in filteredFastas) {
			call Tasks.DustmaskFasta as Dustmasker {
				input:
					fastaFilePath = filteredFna,
					dustmaskerExe = dustmaskerExe
			}
		}

		call Tasks.ConcatenateTextFiles as Cat {
			input:
				fileList = Dustmasker.dustmaskedFile,
				combinedFilePath = outputDir + "/dustmasked.filtered.fna.gz"
		}
	}
}
