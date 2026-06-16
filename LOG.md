# IT-NOW Log

Started in June 2025.

## 10-05-2026

ARDL removed from the final nowcast combination due to poor performance overall.

## 17-01-2026

The infrastructure has undergone a systematic revision, and multiple changes were made.

## 14-06-2025

To match vector sizes, we added the command below on line 177. Check this again next month.

```matlab
Quarters = Quarters(1:end-1); % Check next time whether this is correct.
```
