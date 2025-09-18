# Mobile Phone Specifications - SQL Data Cleaning Project

This project showcases a complete data cleaning and transformation pipeline executed entirely in MySQL. It takes a raw, semi-structured CSV file containing mobile phone specifications and processes it into a clean, well-structured, and analysis-ready table.

The script demonstrates advanced SQL techniques for parsing, standardizing, and structuring data, making it a valuable asset for any data analytics or business intelligence task. 📈

---

## Key Techniques Used

The entire cleaning process is encapsulated in a single, idempotent SQL script that leverages modern MySQL 8+ features:

* **Regular Expressions (`REGEXP_SUBSTR`, `REGEXP_REPLACE`):** Heavily used to extract specific data points (like RAM, chipset, battery capacity) from unstructured text fields.
* **Advanced String Manipulation (`SUBSTRING_INDEX`, `LOCATE`):** Employed to split combined fields into their constituent parts, such as separating performance, display, and camera specs.
* **Conditional Logic (`CASE` Statements):** Used extensively to handle variations in data, standardize units (e.g., converting MHz to GHz, MB to GB), and categorize features (e.g., determining resolution category from pixel height).
* **Structured Workflow:** The script follows a logical flow, using temporary staging columns (e.g., `cores`, `resolution_in_px`) to hold intermediate values, which are then processed and dropped during a final cleanup phase.
* **Data Validation:** Concludes with final verification and a data quality summary to provide a quantitative overview of the cleaned dataset's completeness.

---

## 🚀 How to Run the Script

To replicate the data cleaning process, follow these steps:

1.  **Setup Database:** Create a new MySQL database.
    ```sql
    CREATE DATABASE IF NOT EXISTS 91_mobiles;
    USE 91_mobiles;
    ```
2.  **Enable Local File Loading:** Ensure `LOAD DATA LOCAL INFILE` is enabled on your MySQL server, as this is required to import the CSV.
3.  **Update File Path:** Open the `mobile_specs_cleaning.sql` script and update the file path in the `LOAD DATA` command to point to the location of your raw CSV file.
    ```sql
    -- Update this line in the script
    LOAD DATA LOCAL INFILE 'C:/path/to/your/91_mobiles_uncleaned.csv'
    ```
4.  **Execute Script:** Run the entire `mobile_specs_cleaning.sql` script from top to bottom. The script is designed to be re-runnable without errors.

---

## Final Table Schema

The final output is a table named `cleaned_data` with the following analysis-ready columns:

| Column | Data Type | Description |
| :--- | :--- | :--- |
| `id` | `INT` | Unique identifier for each record. |
| `mobile` | `CHAR(255)` | Name of the mobile phone. |
| `price` | `INT` | Price of the phone. |
| `spec_score` | `INT` | A specification score out of 100. |
| `operating_system` | `CHAR(100)` | The base operating system (e.g., Android, iOS). |
| `os_version` | `CHAR(10)` | The version number of the OS. |
| `no_of_cores` | `INT` | Number of CPU cores. |
| `clock_speed_ghz` | `DOUBLE` | Max CPU clock speed in GHz. |
| `chipset` | `CHAR(100)` | The processor/chipset name. |
| `ram_in_gb` | `DOUBLE` | RAM capacity in Gigabytes. |
| `storage_in_gb` | `DOUBLE` | Internal storage capacity in Gigabytes. |
| `expandable_storage_in_gb` | `DOUBLE` | Max supported expandable storage in Gigabytes. |
| `display_size_in_inches`| `DOUBLE` | Screen size in inches. |
| `display_size_in_cm` | `DOUBLE` | Screen size in centimeters. |
| `resolution` | `CHAR(50)` | Display resolution category (e.g., FHD+, QHD). |
| `px_width` | `INT` | Display width in pixels. |
| `px_height` | `INT` | Display height in pixels. |
| `display_type` | `CHAR(50)` | Display panel technology (e.g., AMOLED, LCD). |
| `rear_camera` | `CHAR(255)` | Full text description of the rear camera setup. |
| `primary_cam_mp` | `DOUBLE` | Megapixels of the primary rear camera. |
| `front_camera` | `CHAR(255)` | Full text description of the front camera. |
| `front_cam_mp` | `DOUBLE` | Megapixels of the primary front camera. |
| `flash` | `CHAR(50)` | Type of camera flash. |
| `battery_mah` | `INT` | Battery capacity in milliampere-hours. |
| `charging_port` | `CHAR(50)` | Type of charging port (e.g., Type-C). |
| `usb_version` | `TEXT` | The USB standard version. |
| `charging_type` | `CHAR(50)` | Fast charging technology name. |
| `removable_battery` | `TEXT` | Indicates if the battery is user-removable ('Yes'/'No'). |
| `sim` | `CHAR(100)` | SIM card configuration (e.g., Dual SIM). |
| `wifi_calling` | `TEXT` | Indicates support for WiFi Calling ('Yes'/'No'). |
| `fingerprint_sensor` | `TEXT` | Indicates presence of a fingerprint sensor ('Yes'/'No'). |
| `protection` | `CHAR(30)` | Device protection rating (e.g., IP68). |
