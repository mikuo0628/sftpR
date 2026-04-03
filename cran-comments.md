## R CMD check results

0 errors | 0 warnings | 1 note

* This is resubmission after addressing
  - misuse of single quotes.
  - replace `dontrun` with `donttest`: these examples are meant to show
    users __how__ to use. The supplied parameters work in test and dev
    environments but will largely be different for users.
