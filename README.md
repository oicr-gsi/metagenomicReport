# metagenomicReport

A workflow for checking Fastq files for possible contamination with reads from species other than human, primarily cell culture samples

## Overview

![Workflow Diagram for metagenomicReport](docs/MR_WorkflowDiagram.png)

## Dependencies

* [kraken2 2.0.8](https://ccb.jhu.edu/software/bracken/index.shtml)
* [bracken 2.7](https://ccb.jhu.edu/software/bracken/index.shtml)


## Usage

### Cromwell
```
java -jar cromwell.jar run metagenomicReport.wdl --inputs inputs.json
```

### Inputs

#### Required workflow parameters:
Parameter|Value|Description
---|---|---
`fastqR1`|File|Fastq R1
`fastqR2`|File|Fastq R2
`outputPrefix`|String|Output is, usually sample name

#### Optional task parameters:
Parameter|Value|Default|Description
---|---|---|---
`krakenReport.modules`|String|"kraken2/2.0.8 kraken2-pluspf-database/1"|Names and versions of modules needed for read classification
`krakenReport.krakenDb`|String|"$KRAKEN2_PLUSPF_DATABASE_ROOT/"|Path to bracken/kraken db
`krakenReport.krakenOut`|String|"/dev/null"|Redirect kraken2 output, default is /dev/null
`krakenReport.timeout`|Int|24|Timeout in hours for this task
`krakenReport.jobMemory`|Int|20|Java memory for Kraken
`brackenReport.modules`|String|"bracken/2.7 kraken2-pluspf-database/1"|Names and versions of modules needed for read ratio estimation
`brackenReport.krakenDb`|String|"$KRAKEN2_PLUSPF_DATABASE_ROOT/"|Path to bracken/kraken db
`brackenReport.classLevel`|String|"S"|Classification level, default S (species)
`brackenReport.readLength`|Int|100|Expected read length
`brackenReport.threshold`|Int|10|minimum number of reads required for a classification
`brackenReport.timeout`|Int|24|Timeout in hours for this task
`brackenReport.jobMemory`|Int|20|Java memory for Bracken
`brackenReport.minRatio`|Float|0.03|Threshold for reporting species, minimum read proportion in the analyzed sample


### Outputs

Output | Type | Description | Labels
---|---|---|---
`textReport`|File|a report text file generated by Bracken|vidarr_label: textReport
`jsonReport`|File|json report with bracken-collected estimates|vidarr_label: jsonReport


## Commands
 
This section lists command(s) run by metagenomicReport workflow

* Running metagenomicReport

### Kraken2

Kraken2 accepts paired fatq files and runs classificatiion of reads using k-mer database of 
various bacterial, fungal, protozoan and viral species.

```

kraken2 --paired FASTQ_R1 FASTQ_R2 
        --db KRAKEN_DB 
        --report SAMPLE.kreport2.txt 
        --output /dev/null

```

### Bracken

Bracken (Bayesian Reestimation of Abundance with KrakEN) is a highly accurate statistical method
that computes the abundance of species in DNA sequences from a metagenomics sample. Braken uses 
the taxonomy labels assigned by Kraken, a highly accurate metagenomics classification algorithm, 
to estimate the number of reads originating from each species present in a sample. 

```

bracken -d KRAKEN_DB 
        -i KRAKEN_REPORT 
        -o SAMPLE.bracken 
        -r READ_LENGTH 
        -l CLASS_LEVEL 
        -t THRESHOLD

python3<<CODE
import json
import json

report_file = ~{sample}.bracken
json_name = ~{sample}_brackenReport.json
sampleName = ~{sample}
jsonDict = {sampleName: []}
header = []
limit = ~{minRatio}    # minimum read fraction to consider as contamination

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

```

# Support

For support, please file an issue on the [Github project](https://github.com/oicr-gsi) or send an email to gsi@oicr.on.ca .

_Generated with generate-markdown-readme (https://github.com/oicr-gsi/gsi-wdl-tools/)_
