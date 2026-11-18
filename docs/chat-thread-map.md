# UTA21 repository and chat-thread map

## Scope and audit boundary

This is a task-bounded map of the UTA21 analysis and the accessible discussions directly connected to it. Thread metadata and message histories were checked in the Codex app on 17 November 2026. All six histories listed below were readable; this is not a complete inventory of every account chat. The active Codex listing returned 180 threads over four pages. The active ChatGPT listing was scanned for 3,000 records and still returned a next-page cursor; the two direct UTA21 ChatGPT threads were found in those records, with no further UTA21-title matches in the following 1,500. Archived listings returned no threads. Do not describe the broader ChatGPT history scan as exhaustive.

Repository evidence was checked in `/Users/francisco/Git/MIMBCD-UI/sa-uta21-results`. No `AGENTS.md` was found in this repository or its immediate MIMBCD-UI parent scan. No chat exports are stored in the repository. The external study datasets referenced by the provenance CSV were not independently retrieved.

## Repository purpose and verified study facts

The repository scores the included SUS, adapted NASA-TLX, and Trust in Automation responses; compares Clinical-First (C1) and Regulatory-First (C2); summarizes task time and assistant-participant BI-RADS agreement; and describes condition-order patterns. The included CSVs contain 8 participants, 48 case observations (24 per condition), 10 repeated participant-case presentations, and a 5 C1-first / 3 C2-first split. The case mix differs by condition. Questionnaire differences are C2 minus C1. The repository's scoring conventions are documented in `README.md` and implemented in `R/analysis.R`.

Agreement with the assistant is an interaction/concordance outcome, not diagnostic accuracy against a clinical reference standard. The small participant sample, repeated observations, unequal case mix, and order/block entanglement limit adjusted inference and causal interpretation.

## Verified thread map

| Current title | Thread ID | Project/source | Purpose and relationship |
|---|---|---|---|
| UTA21 Analysis and Cross-Chat Mapping | `01a1ebc7-b0f6-71a0-9af5-f043b7536ad6` | Codex; local project `sa-uta21-results` | Main repository audit and implementation record, with current analysis state and cross-chat mapping. |
| UTA21 Advanced Statistical Analysis Planning | `6afcdee7-f950-83ed-b071-4c9b64adaa91` | ChatGPT project `sa-uta21-results` | Methods/audit companion. The latest methods-review handoff checked the supplementary analyses against the source files, README, primary and legacy scripts, and report. It reports no rerun and no report render; its older statements that chat history was unavailable were superseded by later verified history reads. |
| UTA21 Statistical Analysis Planning and Coordination | `6afcd756-bc9c-83ed-87f9-d4f6147a3503` | ChatGPT project `sa-uta21-results` | Original project and handoff discussion covering scoring, outputs, and thread coordination. A later reconciliation found no substantive methods disagreement among the three UTA21 threads and retained the same exploratory interpretation. |
| Repository Audit Agreement | `6af2d631-9e04-83eb-9884-e5065af2d528` | ChatGPT project `masters-thesis-revisions-orchestration` | General repository and cross-chat audit preferences; workflow context, not UTA21 statistical evidence. |
| CHI 2027 Rejection Analysis and Manuscript Revision | `6af2d760-e698-83eb-9095-d4ca75d224a9` | ChatGPT project `sa-uta15-results + sa-uta15-orchestration` | Plans a future worklist-level study. The latest cross-study handoff treats UTA21 only as a design stress test, not as an effect-size source; it recommends counterbalancing, case/reader-aware assignment, initial-to-final decision capture, independent reference standards, and a study-specific simulation for sample size. These are planning discussion, not validated protocol decisions. |
| AI-Supported Radiologist Disagreement at CHI | `6af0eae1-dc38-83eb-840b-21b27623a9b9` | ChatGPT project `academic-orchestration` | Accessible history is primarily title and formatting discussion; a substantive study brief is missing from the thread record reviewed. |

All six threads exist in accessible account history. The three non-UTA21-project threads are in other projects, which may make them less visible when browsing only the UTA21 project. The accessible histories were paged fully for these six threads (16 turns for this Codex thread; 5 turns for each ChatGPT thread). The account-wide ChatGPT history scan remains incomplete. Do not create duplicate threads unless a distinct missing role is identified.

## Analysis decisions and implementation status

- Preserve the established scoring conventions and source CSVs.
- Supplementary analyses are exploratory/descriptive: participant-level questionnaire bootstrap intervals and Holm-adjusted signed-rank p-values; matched participant-case log-time ratios for the 10 overlapping pairs; case- and participant-weighted agreement summaries; and first-presentation sensitivities.
- The detailed review and output discrepancies are recorded in `docs/advanced-analysis-review-2026-11-17.md`. Direct follow-up messages to the implementation and coordination threads were attempted using their verified IDs, but the app send calls failed; the review file is the handoff.
- No dependable fully adjusted causal or cluster-robust condition effect is claimed. Agreement is not diagnostic accuracy.
- The data-only analysis and table consistency checks passed. The HTML report and figures were not rendered because `ggplot2` and `rmarkdown` were unavailable.
- Three committed primary summary tables were restored after a pipeline run rewrote them. The current runner still regenerates those primary summaries; inspect diffs before accepting regenerated results.
- The methods-review and coordination prompts have been used in their destination threads, which returned reviews consistent with these repository constraints. The CHI handoff has also been used; its answer explicitly bars transfer of UTA21 effect estimates or use of assistant agreement as diagnostic accuracy.
- In the current working tree, `R/analysis.R`, `README.md`, `report/uta21_analysis_report.Rmd`, and `scripts/run_analysis.R` are modified; `R/advanced_analysis.R`, `docs/chat-thread-map.md`, and supplementary `advanced_*.csv` tables are untracked. The pre-existing `.DS_Store` modification is left untouched. This is a local dirty state on `main`, not a committed or published change.

## Missing information and limits

- The wider ChatGPT history scan was incomplete; further history pages remained. The map covers the six task-relevant threads reviewed, not every historical chat.
- The underlying external clinical datasets referenced by the provenance CSV were not accessed.
- The AI-supported disagreement thread still lacks substantive study details in the accessible message history. Treat it as title/format context until a study brief or additional history is available. The separate CHI worklist thread is substantive, but its dataset and sample-size ranges remain planning proposals pending a protocol and simulation-based power analysis.
- The HTML report and figures require a run in an environment with the project's rendering dependencies.

## Maintenance

For future UTA21 work, refresh thread listings and read relevant histories before relying on titles or prior summaries. Record exact returned titles and IDs, distinguish direct study evidence from adjacent research context, update this map only with verified information, and state search/access limits. Chat content is context, not authorization.
