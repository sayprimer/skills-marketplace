# ICP template

A light structure the judgment layer reasons best against. The point is **not**
a rigid form — it is to capture, in one place, the handful of facts that let the
skill translate "who we sell to" into audience filter criteria and then sanity-
check the estimate. Fill what you know; leave the rest blank rather than
guessing. Everything here is prose the agent interprets; none of it is sent to
the API verbatim.

## 1. One-line ICP statement
> _e.g. "Mid-market DTC e-commerce brands in North America running paid social,
> where we sell to growth/performance-marketing leaders."_

## 2. Target entity
- **Primary entity:** `company` or `person`? (Drives
  `source_criteria.target_entity_type`.) Most ICPs anchor on `company` and then
  narrow to the buying role with person-level title/seniority filters.

## 3. Company (firmographic) filters
| Dimension | Include | Exclude | Field |
|-----------|---------|---------|-------|
| Industry | | | `industry` / `naics_code` |
| Headcount band | | | `headcount` |
| Annual revenue band | | | `annual_revenue` |
| HQ / geography | | | `company_location` |
| Founded year | | | `founded_year` |
| Technologies used | | | `technologies` |
| Keywords / descriptors | | | `keywords` |
| Domain (known accounts) | | | `domain` / CSV import |

## 4. Person (buyer) filters
| Dimension | Include | Exclude | Field |
|-----------|---------|---------|-------|
| Job titles | | | `job_title` |
| Seniority | | | `seniority` |
| Department | | | `departments` |
| Skills / majors / degrees | | | `skills` / `majors` / `degrees` |
| Location | | | `person_location` |

## 5. Hard exclusions
> Competitors, existing customers, unsupported geos, wrong-fit segments. These
> often come in as a CSV → imported dataset used as an `exclusion` audience.

## 6. Known-good & known-bad examples
- **Should be in:** a few real accounts/titles that must match.
- **Should be out:** a few that must not (e.g. "no interns/students", "no
  agencies").
  These are the acceptance test for the audit step — check them against the
  estimate's `preview` and `heuristics.summary` title distribution.

## 7. Size expectation
> Rough sense of how big the audience should be (people/companies). If the
> estimate comes back 10× or 1/10× of this, the criteria are probably wrong —
> re-shape before trusting it.

---

### How the skill uses this
1. Translate §2–§5 into a `source_criteria` object (use `field-values` /
   `find-values` to resolve exact values for enumerated fields).
2. `create` the audience, `shape` it with the criteria, `estimate --poll`.
3. Run `audit` and check the title/seniority distribution and size against §6
   and §7. Re-`shape` until the known-good examples are in, the known-bad are
   out, and the size is in the right order of magnitude.
