# Editorial policy

Use this policy after collection and before preparing `evidence.md`.

## Contents

- [Hard gates](#hard-gates)
- [Ranking](#ranking)
- [Required story shape](#required-story-shape)
- [What stays small](#what-stays-small)
- [Visual evidence](#visual-evidence)
- [Coverage decisions](#coverage-decisions)
- [Output contracts](#output-contracts)

## Hard gates

Keep a claim only when all are true:

- A primary official source supports the capability.
- The compared revision/version range plausibly contains it.
- The change affects something the user can do, see, configure, or understand.
- Its activation state can be stated honestly.
- It has not already been covered at the same target.

Leave a component pending when its source, target, ancestry, or applicability is
uncertain.

## Ranking

Score each surviving capability from 0 to 2 on each dimension:

| Dimension | 0 | 1 | 2 |
| --- | --- | --- | --- |
| New possibility | Maintenance only | Improves an existing action | Enables a distinct workflow |
| Local fit | Generic | Relevant to an installed component | Direct fit with this config/languages |
| Visibility | Internal | Noticeable with explanation | Immediately visible or testable |
| Tryability | No safe demonstration | Explainable example | Small concrete try-it path |
| Evidence | Indirect/unclear | One adequate primary source | Strong docs plus example or visual |

Rank by total score, then editorial variety. Select at most seven. There is no
minimum: publish a quiet-cycle brief when nothing clears the hard gates.

## Required story shape

Every primary discovery answers, in this order:

1. What can I do now?
2. Why would I care?
3. Where does it fit in my setup?
4. How can I try or visualize it?
5. Is it automatic, update-dependent, opt-in, or integration-dependent?
6. Which primary sources support those claims?

Paraphrase evidence around user benefit. Do not reproduce changelog entries.

## What stays small

- Put routine fixes, refactors, dependency bumps, and invisible performance
  work into a collapsed maintenance count or `no_learning_value` coverage.
- Mention a breaking change only when it is necessary to understand or try a
  featured capability.
- Put smaller user-visible refinements in “Smaller sparkles”; do not inflate
  them into full stories.
- Include at most two adjacent tools, and only with evidence of direct local
  fit. Popularity alone never qualifies.

## Visual evidence

Use an official screenshot when it genuinely shows the new capability and the
source permits reuse or capture. Otherwise request an explanatory workflow,
state-change, or before/after diagram. Never fabricate a product interface.

## Coverage decisions

- `featured`: the report deliberately covers the component through the stated
  target.
- `no_learning_value`: the inspected range was confidently maintenance-only.
- omitted: research, comparison, evidence, or applicability remains incomplete.

Coverage is about whether a range was handled, not whether an update was
installed.

For Lazy components, `through` must exactly equal the manifest's collected
`target`. For Mason components, use the exact upstream version established by
the cited primary evidence; it may be newer than the installed receipt.

## Output contracts

Write `coverage.json` beside the manifest:

```json
{
  "processed": [
    {
      "component_id": "lazy:owner/repository",
      "through": "revision-or-version",
      "disposition": "featured"
    },
    {
      "component_id": "mason:tool-name",
      "through": "version",
      "disposition": "no_learning_value"
    }
  ],
  "adjacent": ["github:owner/repository"]
}
```

Write `evidence.md` beside it. Give every selected feature these seven slots:

1. capability statement;
2. local benefit;
3. enabled workflow and small try-it path;
4. activation status;
5. exact primary sources and what each supports;
6. approved screenshot path/URL or honest diagram suggestion;
7. only the caveat needed to understand the feature.

Also record the coverage period, collection gaps, smaller visible improvements,
collapsed maintenance count, and quiet-cycle message when nothing qualifies.
Keep raw research out of this presentation bundle.
