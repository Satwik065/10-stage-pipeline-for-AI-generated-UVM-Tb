cat > deliverables/stage7_notes.md <<'EOF'
# Stage 7 — Coverage (N/A Disclosure)

Coverage analysis (covergroups, bin reachability) is deferred to a
companion DUT.

**Reason:** The frozen AI-variant prompts (Stage 4) did not require
covergroups. Coverage is orthogonal to the pipeline's gate metric
(T / C_dev), which scores detection of injected mutants, not
stimulus distribution.

**What would change if covered:** A "thoroughness" signal on top of
T / C_dev — useful for reporting, not used for survivor selection in
this experiment.

**Extension path:** Add a required covergroup to the driver prompt,
re-run Stage 4-5, report coverage of survivors vs. Best-Known-Good.
EOF