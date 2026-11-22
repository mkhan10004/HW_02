# Homework 02 evidence checklist

Use this checklist to write your Word or PDF submission after testing. At the top of your document include your name, Homework 02, test date, GitHub URL, Android device and OS, APK build version and SHA-256. Give each screenshot a number and caption it with the action, expected result, observed result, and Pass/Fail.

| ID | Action | Expected result |
| --- | --- | --- |
| T01 | Launch the exact release APK. Record launch if needed to capture the splash. | Splash appears and gives way to sign-in. |
| T02 | Register as test account A and finish the profile. | Board opens. Firebase Auth lists A. Firestore `users/{uid}` contains all five fields and a matching UID. |
| T03 | Sign out, try a malformed email and then an incorrect password. | Each attempt gives helpful feedback and leaves the user signed out. |
| T04 | Sign in successfully, fully stop the app, then relaunch. | Session resumes and the board remains accessible. |
| T05 | With a fresh board, capture the empty state. Create two disposable posts. | First post appears without refreshing, and both documents have server timestamps. |
| T06 | Edit one post, then delete it. | Edited text appears automatically, then only the targeted post disappears. |
| T07 | Keep A's board open. Post from B on a second device using the same APK. | A sees B's message without refreshing. |
| T08 | Sign out and tap **Test signed-out board read**. | Firestore returns `permission-denied`. |
| T09 | On B, use the rules-check menu on A's disposable post to test update and delete. | Both attempts return `permission-denied`, and A's post is intact. |
| T10 | Rapid-tap **Post** with one distinctive message. | The board and Firestore show exactly one matching document. |
| T11 | Try posting offline, then reconnect and retry. | The transaction does not complete offline. A successful retry creates one message. Record the actual timing and feedback. |
| S01 | Seed local emulator data and compare with production. | Test records appear in Emulator UI only. |
| S02 | Run the rules unit tests. | Capture the actual test summary and named cases. |
| S04 | Run the same-ID transaction test and pair it with T10. | Two concurrent calls using the same operation ID leave one document. |

## Release Readiness Gate

Record T01–T10 using the exact APK you will attach. Record the actual results even when they differ from the expectations. Capture the profile and database checks in the Firebase console using fictional test data.

## Written work

- **Two case files.** Suggested selections are The Ghost Editor and The Runaway Dupes. For each, write your diagnosis, choice, trade-off, and test. Reference T09 or T10/S04 where they support your conclusion.
- **AI Lab.** Record your own five persistence predictions before using an instructor-approved AI tool for the lab. Track session, private profile, shared messages, cached reads, and unsent drafts through relaunch, reboot, and clearing app data. Record the tool/date, its suggestions in your words, one claim you confirmed, one you corrected or tested, the official source you checked, and what you ultimately decided. Disclose AI assistance with implementation under your course policy.
- **Reflection.** Answer the assignment's prompts using your own observations. Cover expectation vs. actual behavior and root cause, a debugging example and an alternative fix, one improvement, private data excluded from app-managed storage, cloud vs. device placement, and your first change at 10,000 users and 100,000 messages.
- **Submission.** Include the GitHub URL with source and README, the exact installed APK, and the single PDF or Word document with screenshots and written work.
