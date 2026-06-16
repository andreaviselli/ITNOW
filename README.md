# ITNOW MATLAB Pipeline Instructions

Please follow these steps in order to successfully obtain nowcasts of Italian nominal GDP growth.

## 1. Download and prepare the data

Open the file `GetData.m`.

1. Set the path to the replication folder at line 31, for example:

   ```matlab
   base_path = ".../matlab-code/";
   ```

2. At lines 19--20, change the `edition` and `preliminary_ed` strings to the current month in the format `%yyyyM%mm`, for example:

   ```matlab
   edition = "2024M12";
   preliminary_ed = "2024M12";
   ```

   There exist several editions for historical data as well.

3. Run the file. If an error of the type

   ```text
   Edition XXXXXXX of GDP not available
   ```

   occurs, retry using previous months' editions and preliminary editions, and continue as soon as this is successfully overcome. Knowledge of vintage release dates is necessary for an exact download.

The new dataset vintage will be stored in:

```text
~/IT-NOWCAST/DATA/dataYYYYMMDD
```

A separate file will be created for GDP only at:

```text
~/IT-NOWCAST/DATA/GDP_History/GDPYYYYMMDD.csv
```

where `YYYYMMDD` is the date format, and the current date will be used.

## 2. Run the historical forecasting pipeline

Open the file `GetHistFcast.m`.

1. Set the path to the replication folder at line 3, for example:

   ```matlab
   base_path = ".../matlab-code/";
   ```

2. Replace the vintage date string at line 16 by changing the variable `vintage`, for example:

   ```matlab
   vintage = "YYYYMMDD";
   ```

   This is the date when the data were downloaded in the previous step.

3. Set `save_fcast = 1` at line 19 to save the results.

4. Set `RemoveCovid = 0`, which is the default and should always be used in our case.

5. Set `Eval_End` equal to the desired month where the evaluation must finish, for example:

   ```matlab
   Eval_End = datetime("yyyy-mm-dd");
   ```

6. Run the file. This may take some time.

## 3. Retrieve the results

The results, including figures and tables, are returned after the forecasting pipeline is finished.
