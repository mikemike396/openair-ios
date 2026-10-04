# App Store metadata

This directory records the US English metadata prepared for each OpenAir release. The files here are drafts until their status is changed to **submitted** or **live** after checking App Store Connect. Codex maintains these records; the app owner enters and submits metadata in App Store Connect.

## Version workflow

1. Before a release, create `VERSION/en-US.md` with the proposed public copy and its rationale.
2. When the owner enters the copy in App Store Connect, compare the saved fields and update the file to match what was actually submitted. Record the submission date.
3. Once live, record the release date. Keep that version's snapshot unchanged; use a new directory for later edits.
4. Compare App Store Search impressions, first-time downloads, and conversion over equal periods. Record major changes to screenshots, paid acquisition, or app behavior alongside metadata changes.

The keyword field is recorded in each version's metadata file and is intended to be public. Analytics, API credentials, collection scripts, and weekly reviews are maintained in a separate, private ASO workspace outside this app repository. This directory retains public version snapshots. Preserve the period, territory filter, source, and metric definition so later comparisons are meaningful. Analytics are not committed to Git and need a separate private backup.

Apple limits app names and subtitles to 30 characters and the keyword field to 100 bytes. Promotional text is limited to 170 characters. Verify counts before entering new copy in App Store Connect.
