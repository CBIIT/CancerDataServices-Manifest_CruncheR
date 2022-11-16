# CancerDataServices-Manifest_CruncheR
This script will take either a bucket with a grep term to pull all CDS manifest submission files, or a directory with CDS manifest submission files and concatenate them into one file.

To run the script on a [CDS template](https://github.com/CBIIT/cds-model/tree/main/metadata-manifest), run the following command in a terminal where R is installed for help.

```Rscript --vanilla CDS-Manifest_CruncheR.R -h```

```
CDS-Manifest_CruncheR v2.0.0

Please supply the following script with the AWS bucket location and grep term or a directory with the submission templates, and the CDS template file.

Options:
	-b CHARACTER, --bucket=CHARACTER
		The base AWS bucket location of the files, e.g. s3://bucket.location.is.here/

	-g CHARACTER, --grep=CHARACTER
		The term/pattern that will filter the submission files from the rest of the files in the bucket. To test your grep term, please try the following command in command line interface: aws s3 ls --recursive s3://bucket.location.is.here/ | grep 'grep_term'.

	-d CHARACTER, --directory=CHARACTER
		If all the files are already downloaded from a bucket into a directory, selecting this option will bypass the bucket portion of the script and concatenate the submission templates that are available in the directory.

	-t CHARACTER, --template=CHARACTER
		dataset template file, CDS_submission_metadata_template-v1.3.xlsx

	-h, --help
		Show this help message and exit
```

An example using test data to run this script with a directory of multiple submission files:

```
Rscript --vanilla CDS-Manifest_CrunchR.R -t CDS_submission_metadata_template-v1.3.xlsx -d test_files/test_folder/
```

The CDS_submission_metadata_template can be found in this [repo](https://github.com/CBIIT/CancerDataServices-SubmissionValidationR).
