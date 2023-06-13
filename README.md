# senior-data-engineer-coding-interview

Thanks for taking the time to invite me to partake in the techical interview I've submitted my attempt at this challenge as requested.

There are a few caveats I'd like to mention, in keeping with my intial communication I've submitted this without testing the additional changes, namely:

- EC2 SFTP access, I doubt that mount command is going to work
- Scheduling and an orchestration, I believe the foundation is there, however it may need some tweaking
- ETL.py -- I can't seem to get the files name correctly, should I be unsucessfull, I'd appreciate some feedback on this.

As mentioned to Nix, Terraform isn't my strong point so a lot of testing was done hence the testing_sql directory contains the SQL data used for testing - I managed to spin up a RDS database and do the testing live.

Additional learnings are not to use Notebooks in glue as they're fairly expensive, as now I owe Amazon R157 :blush: as well as the JDBC connection not liking the latest version of Postgres, I had to settle on using 13.11

Anyway, thanks again.
Nathan
