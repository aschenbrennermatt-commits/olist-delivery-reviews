# Data notes

A running log of every data quirk found and what was done about it. Interviewers ask about these, so each row says *why*.

## Found while building the database (step 1)

| # | What I found | What I did | Why |
|---|---|---|---|
| 1 | `customer_id` is new for every order. 99,441 customer_ids map to only 96,096 real people (`customer_unique_id`). | Kept both columns and indexed `customer_unique_id`. Made `orders.customer_id` UNIQUE. | Counting repeat customers with `customer_id` would show almost nobody ever comes back. Any per-person analysis must use `customer_unique_id`. |
| 2 | `review_id` is not unique: 814 rows reuse a review_id that's attached to a different order. | Primary key is `(review_id, order_id)`. | The combination is unique. Dropping the "duplicates" would delete real order-review links. |
| 3 | 547 orders have 2 or more reviews. 768 orders have none. | Kept one review per order: the most recent answer (latest `review_answer_timestamp`, ties broken by `review_id`). See `sql/10_latest_review.sql` and the `analysis_orders` view. Orders with no review are left out of the review analysis. | Joining orders to reviews would count some orders twice. A robustness check using each order's *first* review gives the same result (late effect -2.01 stars); only 188 orders score differently. |
| 4 | Two categories used by 13 products (`pc_gamer`, `portateis_cozinha_e_preparadores_de_alimentos`) are missing from the translation file. | Added them to `category_translation` with my own English names. | Keeps the foreign key from products to categories instead of dropping it. |
| 5 | 610 products have no category (and no name/description/photo counts). 2 have no dimensions. | Allowed NULLs. In the review analysis, orders whose main product has no category are labelled "unknown". | Real missing data. Labelling keeps those orders in the regression instead of dropping them. |
| 6 | Geolocation has ~1M rows for 19,015 zip prefixes, including ~262k exact duplicate rows. 278 customer zips and 7 seller zips are missing from it. | Loaded as-is with a surrogate id, no foreign keys to it. | There is no natural key. If maps are needed later, build one row per zip (e.g. median lat/lng). |
| 7 | Zip prefixes like `01151` have leading zeros. | Stored as `CHAR(5)`, not a number. | A numeric type would turn `01151` into `1151` and break joins. |
| 8 | Products CSV misspells two columns (`product_name_lenght`, `product_description_lenght`). | Renamed to `..._length` in the table. | Cleaner queries. COPY loads by position, so loading is unaffected. |
| 9 | 8 orders are `delivered` but have no delivery date. 6 `canceled` orders do have one. | The review analysis keeps only `delivered` orders that have a delivery date, so the 8 are excluded and canceled orders are out of scope. | Late vs on-time can't be computed without a delivery date, and canceled orders were never delivered. |
| 10 | `review_creation_date` is midnight in all but 85 rows. It's when the survey was sent, not when the customer answered. | Kept as TIMESTAMP. | `review_answer_timestamp` is when the customer actually answered. |

## Decisions made in step 2

- **GMV** = sum of item prices (`order_items.price`), no shipping, excluding canceled and unavailable orders. Orders still in transit are included.
- **Trend window:** Jan 2017 – Aug 2018. 2016 is sparse with a missing month; Sep–Oct 2018 were cut off by the snapshot, so most of those orders weren't delivered yet.
- **Minimum sample sizes:** state comparisons need 100+ delivered orders (drops RR and AP); seller comparisons need 30+ orders.
- **Key finding:** northern states (RR, AP, AM) are slowest but rarely late because their promised windows are long (~46 days). Northeastern states (AL, MA, SE) are late most often, with tighter promises (~31–33 days). Customers seem to react to missed promises, not slowness itself.

## Decisions made in step 3

- **One review per order:** the most recent answer (#3). The first-review robustness check matches: -2.01 stars either way.
- **Definition of "late":** the delivered date is later than the estimated delivery date, compared as calendar dates. An order delivered on its promised day counts as on time.
- **Scope:** `delivered` orders with a delivery date and at least one review (#9). That leaves 95,824 orders, of which 6,381 (6.7%) were late.
