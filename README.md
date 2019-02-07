# modsocsys-grader
Canvas LMS-integrated grading system for Prof. Paul Smaldino's COGS 122: Modeling Social Systems at UC Merced.


## Motivation and approach

I want to build a flexible yet practical system that, for now, grades assignments for the course. 
But I also have an eye towards a more general, but still light-weight, 
application for grading programming assignments. So this is partly a prototype for that. It probably
won't be as general as it would need to be, but I will build in generality as it is expedient and
appropriate.


### Plans and ruminations on how the software should be

I want this software to be open source, so one design requirement is that the assignments and their
solutions are not part of the software itself. My current solution is to define these
in JSON files with a specific structure. 

Perhaps it would be just as easy to read a copy/pasted version
of Paul's assignment files into the specified JSON format. Then adding a new professor's
format would just be a matter of defining a new adapter to turn it to the JSON format.
New assignments could be written directly in the JSON format, or maybe a simple web app
front end with a form to write new assignments that will be saved directly to the JSON format.
No reason to use a database for this stuff, is there? Just keep it all in a single JSON, it won't be
too big. 
