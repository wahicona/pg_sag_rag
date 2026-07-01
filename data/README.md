# Data Directory

Large benchmark source files are intentionally not committed.

For the HotpotQA adapter, place the dev-distractor JSON file here:

```text
data/hotpot_dev_distractor_v1.json
```

Then generate the SQL fixture:

```bash
python3 scripts/hotpotqa_benchmark.py \
  --input data/hotpot_dev_distractor_v1.json \
  --limit 20 \
  --out demo/hotpotqa_sample.sql
```

Generated SQL fixtures under `demo/hotpotqa_sample.sql` and `demo/enterprise_benchmark.sql` are also ignored so they can be rebuilt locally.
