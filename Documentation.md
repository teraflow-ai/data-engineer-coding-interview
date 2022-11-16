# Solution Overview

- The Glue crawler connects to the Aurora Database and creates external tables in the Glue Data Catalog.
- Glue Job joins the tables to create the final Dataframe
- Final Dataframe is written to S3. Data is partitioned by bank name, year and month.
- Using s3-concat library, the S3 files are combined into a single file and the correct naming is applied.
- Step function is used to schedule and orchestrate the Glue Job. 

Architecture :

![](architecture.png)

