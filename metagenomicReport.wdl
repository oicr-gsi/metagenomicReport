version 1.0

workflow metagenomicReport {
input {
    File fastqR1
    File fastqR2
    String outputPrefix
  }

  parameter_meta {
    fastqR1: "Fastq R1"
    fastqR2: "Fastq R2"
    outputPrefix: "Output is, usually sample name"
  }

  meta {
    author: "Peter Ruzanov"
    email: "pruzanov@oicr.on.ca"
    description: "Checking human NGS reads (fastq files) for the presence of reads from fungi, bacteria or viruses. This analysis employs Kraken2 Database and features an estimate of the percentiage of NGS reads coming from contaminating species with Bracken. This workflow cannot be used to detect contamination with other higher order species (i.e. mouse). The running time of this workflow is short and the file system footprint is insignificant.\n\n![Workflow Diagram for metagenomicReport](docs/MR_WorkflowDiagram.png)"
    dependencies: [
      {
        name: "kraken2/2.0.8",
        url:  "https://ccb.jhu.edu/software/bracken/index.shtml"
      },
      {
        name: "bracken/2.7",
        url:  "https://ccb.jhu.edu/software/bracken/index.shtml"
      }
    ]
    
    output_meta: {
    textReport: {
        description: "a report text file generated by Bracken",
        vidarr_label: "textReport"
    },
    jsonReport: {
        description: "json report with bracken-collected estimates",
        vidarr_label: "jsonReport"
    }
}
  }

  call krakenReport {
    input:
      fastqR1 = fastqR1,
      fastqR2 = fastqR2,
      sample = outputPrefix
  }

  call brackenReport {
    input:
      krakenReport = krakenReport.report,
      sample = outputPrefix
  }

  output {
    File textReport = brackenReport.bracken
    File jsonReport = brackenReport.jsonReport
  }
}

# ========================================
# Phylogenetic classification with Kraken2
# ========================================
task krakenReport {
  input {
    String modules  = "kraken2/2.0.8 kraken2-pluspf-database/1"
    String krakenDb = "$KRAKEN2_PLUSPF_DATABASE_ROOT/"
    File fastqR1
    File fastqR2
    String sample
    String krakenOut = "/dev/null"
    Int timeout = 24
    Int jobMemory = 20
  }

  parameter_meta {
    fastqR1: "R1"
    fastqR2: "R2"
    sample: "Sample identifier"
    timeout: "Timeout in hours for this task"
    jobMemory: "Java memory for Kraken"
    modules: "Names and versions of modules needed for read classification"
    krakenDb: "Path to bracken/kraken db"
    krakenOut: "Redirect kraken2 output, default is /dev/null"
  }

  command <<<
   kraken2 --paired ~{fastqR1} ~{fastqR2} --db ~{krakenDb} --report ~{sample}.kreport2.txt --output ~{krakenOut}
  >>>
  
  runtime {
    memory:  "~{jobMemory} GB"
    modules: "~{modules}"
    timeout: "~{timeout}"
  }

  output {
    File report = "~{sample}.kreport2.txt"
  }
}

# ==================================
#  Abundance estimation with Bracken
# ==================================
task brackenReport {
  input {
    File krakenReport
    String modules  = "bracken/2.7 kraken2-pluspf-database/1"
    String krakenDb = "$KRAKEN2_PLUSPF_DATABASE_ROOT/"
    String sample
    String classLevel = "S"
    Int readLength = 100
    Int threshold = 10
    Int timeout = 24
    Int jobMemory = 20
    Float minRatio = 0.03 
  }

  parameter_meta {
    krakenReport: "Report generated with Kraken2"
    sample: "Sample identifier"
    classLevel: "Classification level, default S (species)"
    readLength: "Expected read length"
    threshold: "minimum number of reads required for a classification"
    timeout: "Timeout in hours for this task"
    jobMemory: "Java memory for Bracken"
    modules: "Names and versions of modules needed for read ratio estimation"
    minRatio: "Threshold for reporting species, minimum read proportion in the analyzed sample"
    krakenDb: "Path to bracken/kraken db"
  }

  command <<<
   set -euo pipefail
   bracken -d ~{krakenDb} -i ~{krakenReport} -o ~{sample}.bracken -r ~{readLength} -l ~{classLevel} -t ~{threshold}

   python3<<CODE
   import json

   report_file = "~{sample}.bracken"
   json_name = "~{sample}_brackenReport.json"
   sampleName = "~{sample}"
   jsonDict = {sampleName: []}
   header = []
   limit = ~{minRatio} 

   """For Bracken, we need fields 2,4,5,6 to be int and 7 - float type"""
   def typeCast(reportString):
       stringList = reportString.split("\t")
       if len(stringList) != 7:
           return stringList
       for i in [1, 3, 4, 5]:
           stringList[i] = int(stringList[i])
       stringList[6] = float(stringList[6])
       return stringList

   """Read from Bracken report, convert to json"""
   with open(report_file) as r:
       for line in r:
           lineIn = line.rstrip()
           if lineIn.find("taxonomy_id") > 0:
               header = lineIn.split("\t")
               continue
           tmp = typeCast(lineIn)
           if float(tmp[-1]) < limit:
               continue
           jsonDict[sampleName].append(dict(zip(header, tmp)))
   r.close()

   if len(jsonDict.keys()) > 0:
       with open(json_name, 'w') as json_file:
           json.dump(jsonDict, json_file)
   CODE
  >>>
  
  runtime {
    memory:  "~{jobMemory} GB"
    modules: "~{modules}"
    timeout: "~{timeout}"
  }

  output {
    File bracken = "~{sample}.bracken"
    File jsonReport = "~{sample}_brackenReport.json"
  }
}

