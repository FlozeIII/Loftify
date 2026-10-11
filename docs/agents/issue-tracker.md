# Issue tracker

This project tracks Community work in GitHub Issues at
https://github.com/FlozeIII/Loftify/issues.

Read the issue's acceptance criteria and `Blocked by` links before implementation.
Issue #1 holds the Community distribution spec. Tasks #2–#12 reference it.

Use `gh issue view <number> --repo FlozeIII/Loftify --json title,body,state`
to retrieve a task. Update its acceptance record and close it after all applicable
criteria have been verified, including Windows native checks when required.

For code review, pin the commit before the task began and review both the task
and the relevant sections of #1. Keep validation records linked to their build
and source revision.
