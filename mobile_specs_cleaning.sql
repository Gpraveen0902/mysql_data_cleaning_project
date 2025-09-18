################################################## 91MOBILES DATA CLEANING PROJECT ##################################################
/***********************************************************************************************************************************
*
* SCRIPT: mobile_specs_cleaning.sql
* AUTHOR: Praveenkumar G
* DATE: 2025-9-17
*
* PURPOSE:
* This script cleans and transforms the raw mobile phone specifications data from 'raw_data.csv'.
* It parses semi-structured text fields into well-defined, typed columns for analytical use.
* The final output is stored in the 'cleaned_data' table.
*
* INSTRUCTIONS TO RUN:
* 1. Create a database (e.g., `CREATE DATABASE 91_mobiles;`).
* 2. Use the created database (`USE 91_mobile;`).
* 3. Ensure `LOAD DATA LOCAL INFILE` is enabled on your MySQL server.
* 4. Place 'raw_data.csv' in a directory accessible to the MySQL server.
* 5. Update the file path in the `LOAD DATA` statement (Line ~40).
* 6. Execute the script from top to bottom. The script is idempotent and can be re-run.
*
***********************************************************************************************************************************/
-- =================================================================================================================================
-- SECTION 1: SETUP & INITIAL LOAD
-- =================================================================================================================================

-- Purpose: Create and select the database to ensure all subsequent objects are created in the correct scope.
CREATE DATABASE IF NOT EXISTS 91_mobiles;
USE 91_mobiles;

-- Purpose: Create the initial table to hold the raw CSV data.
-- Using DROP IF EXISTS makes the script re-runnable without errors.
DROP TABLE IF EXISTS raw_data;
CREATE TABLE raw_data (
    Mobile TEXT,
    Spec_Score TEXT,
    Operating_System TEXT,
    Price TEXT,
    Per_Dis_Cam_Bat TEXT,
    Other_Features TEXT
);

-- Import the uncleaned 91_mobiles dataset into the raw_data table
-- Note: Update the file path to match your local environment.
-- `IGNORE 1 ROWS` skips the header row in the CSV.
LOAD DATA LOCAL INFILE 'C:/Users/gprav/OneDrive/Desktop/Data Analysis Course files/Datasets/91 mobiles/91_mobiles_uncleaned.csv' -- <-- IMPORTANT: UPDATE THIS PATH
INTO TABLE raw_data
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

-- Purpose: Create a working copy of the data. This follows the best practice of leaving the raw data untouched,
-- allowing for easy comparison or re-starting the cleaning process without a full reload.
DROP TABLE IF EXISTS data_cleaning;
CREATE TABLE data_cleaning AS
SELECT *
FROM raw_data;

-- =================================================================================================================================
-- SECTION 2: SCHEMA NORMALIZATION
-- (Run the ALTER TABLE statements from section 2 of the documentation here)
-- =================================================================================================================================

-- This block is intended to be run *after* the initial data load into `data_cleaning`.
-- It prepares the working table by renaming columns to the target snake_case format
-- and adding all the new columns that will be populated during the cleaning process.

ALTER TABLE data_cleaning RENAME COLUMN `Mobile` TO mobile;
ALTER TABLE data_cleaning RENAME COLUMN `Spec_Score` TO spec_score_raw;
ALTER TABLE data_cleaning RENAME COLUMN `Operating_System` TO os_raw;
ALTER TABLE data_cleaning RENAME COLUMN `Price` TO price_raw;
ALTER TABLE data_cleaning RENAME COLUMN `Per_Dis_Cam_Bat` TO details_raw;
ALTER TABLE data_cleaning RENAME COLUMN `Other_Features` TO features_raw;

-- Add all target columns with their correct data types.
-- This approach (add all, then populate) is often cleaner than adding them one-by-one.
ALTER TABLE data_cleaning
	ADD COLUMN performance TEXT,
    ADD COLUMN cores TEXT,
	ADD COLUMN display TEXT,
	ADD COLUMN camera TEXT,
	ADD COLUMN battery TEXT,
	ADD COLUMN price INT,
    ADD COLUMN spec_score INT,
    ADD COLUMN operating_system TEXT,
    ADD COLUMN os_version TEXT,
    ADD COLUMN no_of_cores INT,
    ADD COLUMN clock_speed_ghz DOUBLE,
    ADD COLUMN chipset TEXT,
    ADD COLUMN ram_in_gb DOUBLE,
    ADD COLUMN display_size_in_inches DOUBLE,
    ADD COLUMN display_size_in_cm DOUBLE,
    ADD COLUMN resolution TEXT,
    ADD COLUMN resolution_in_px TEXT,
    ADD COLUMN px_width INT,
    ADD COLUMN px_height INT,
    ADD COLUMN display_type TEXT,
    ADD COLUMN rear_camera TEXT,
    ADD COLUMN primary_cam_mp DOUBLE,
    ADD COLUMN front_camera TEXT,
    ADD COLUMN front_cam_mp DOUBLE,
    ADD COLUMN flash TEXT,
    ADD COLUMN battery_mah INT,
    ADD COLUMN charging_port TEXT,
    ADD COLUMN usb_version TEXT,
    ADD COLUMN charging_type TEXT,
    ADD COLUMN removable_battery TEXT,
    ADD COLUMN storage_in_gb DOUBLE,
    ADD COLUMN expandable_storage TEXT,
    ADD COLUMN expandable_storage_in_gb DOUBLE,
    ADD COLUMN sim TEXT,
    ADD COLUMN wifi_calling TEXT,
    ADD COLUMN fingerprint_sensor TEXT,
    ADD COLUMN protection TEXT;


-- =================================================================================================================================
-- SECTION 3: DATA TRANSFORMATIONS
-- =================================================================================================================================

-- --------------------------------
-- 3.1: Spec Score & Price
-- --------------------------------

-- Purpose: Clean and cast spec_score and price from text to integer.
-- REGEXP_REPLACE is used to strip all non-numeric CHARacters before casting.
-- NULLIF handles cases where the field is empty or becomes empty after stripping CHARacters.
UPDATE data_cleaning
SET 
    spec_score = NULLIF(REGEXP_REPLACE(spec_score_raw, '[^0-9]+', ''), ''),
    price = NULLIF(REGEXP_REPLACE(price_raw, '[^0-9]+', ''), '');

-- --------------------------------
-- 3.2: Operating System
-- --------------------------------

-- Purpose: Parse the raw OS string to extract both the standardized operating system name and its version number.
-- For the `operating_system` column, a nested CASE statement is used. It categorizes common OS types like Android and iOS.
-- It applies special logic for the Windows family to accurately differentiate between older 'Windows Mobile', 'Windows Phone',
-- and modern 'Windows' by parsing their respective version numbers from the string.
-- For the `os_version` column, it extracts the first available numeric version. It also performs specific, hardcoded
-- data corrections (e.g., replacing 2.4 with 2.3) to standardize inconsistent version reporting in the raw data before casting to a numeric type.

UPDATE data_cleaning
SET
	operating_system =
		CASE
			WHEN os_raw LIKE '%Android%' THEN 'Android'
			WHEN os_raw LIKE '%iOS%' THEN 'iOS'
			WHEN os_raw LIKE '%Blackberry%' THEN 'Blackberry'
			WHEN os_raw LIKE '%Windows%' THEN
			CASE
				WHEN CAST(NULLIF(REGEXP_SUBSTR(os_raw, '(?<=Windows Mobile )[0-9]+(\\.[0-9]+)?'), '') AS DOUBLE) < 7
				THEN 'Windows Mobile'
				WHEN (CAST(NULLIF(REGEXP_SUBSTR(os_raw, '(?<=(Windows Phone )|(Windows v)|(Windows Phone v))[0-9]+(\\.[0-9]+)?'), '') AS DOUBLE) < 10) OR (os_raw = 'Windows Phone')
				THEN 'Windows Phone'
				WHEN REGEXP_SUBSTR(os_raw, '(?<=(Windows v)|(Windows Phone v))[0-9]+(\\.[0-9]+)?') >= 10
				THEN 'Windows'
			END
			ELSE NULL
		END,
        
	os_version =
        CASE
			WHEN os_raw LIKE '%,%' THEN NULLIF(REPLACE(REPLACE(REPLACE(REGEXP_SUBSTR(SUBSTRING_INDEX(os_raw, ',', 1), '([0-9]+\\.)?[0-9]+'), 2.4, 2.3), 5.2, 5.1), 5.4, 5.1), '')
			ELSE NULLIF(REPLACE(REPLACE(REPLACE(REGEXP_SUBSTR(os_raw, '([0-9]+\\.)?[0-9]+'), 2.4, 2.3), 5.2, 5.1), 5.4, 5.1), '')
		END;


-- ------------------------------------------------------------------------------------
-- 3.3: Pre-processing and Splitting the Main 'details_raw' Column
-- This multi-step process first standardizes delimiters in the raw details string
-- and then parses it into separate columns for performance, display, camera, and battery.
-- ------------------------------------------------------------------------------------

-- Step 3.3.1: Insert consistent comma delimiters before major keywords.
-- This makes the string parsable in a predictable way, as it can now be treated like a comma-separated list.
UPDATE data_cleaning
SET
	details_raw = REPLACE(REPLACE(REPLACE(REPLACE(details_raw, 'Performance','Performance '), 'Display', ', Display '), 'Camera', ', Camera '), 'Battery', ', Battery ');

-- Step 3.3.2: Correct edge cases where the initial replacement incorrectly split keywords.
-- This ensures phrases like "Primary Camera" remain intact.
UPDATE data_cleaning
SET
	details_raw = REPLACE(REPLACE(details_raw, 'Primary , Camera', 'Primary Camera'), 'Front , Camera', 'Front Camera');

-- Step 3.3.3: Normalize all whitespace to single spaces for consistency.
UPDATE data_cleaning
SET
	details_raw = regexp_replace(details_raw, ' +', ' ');

-- Step 3.3.4: Extract the Performance, Display, Camera, and Battery sections into their own columns.
-- This uses a robust parsing method with LOCATE and SUBSTRING. COALESCE is used to find the next available
-- delimiter, which allows the query to work correctly even if a section is missing from the raw data.
UPDATE data_cleaning 
SET 
    performance = CASE
        WHEN
            LOCATE('Performance', details_raw) > 0
        THEN
            TRIM(SUBSTRING(details_raw,
                    LOCATE('Performance', details_raw) + LENGTH('Performance '),
                    COALESCE(NULLIF(LOCATE(', display', details_raw), 0),
                            NULLIF(LOCATE(', Camera', details_raw), 0),
                            NULLIF(LOCATE(', Battery', details_raw), 0),
                            LENGTH(details_raw) + 1) - (LOCATE('Performance', details_raw) + LENGTH('Performance '))))
        ELSE NULL
    END,
    display = CASE
        WHEN
            LOCATE(', display', details_raw) > 0
        THEN
            TRIM(SUBSTRING(details_raw,
                    LOCATE(', display', details_raw) + LENGTH(', display '),
                    COALESCE(NULLIF(LOCATE(', Camera', details_raw), 0),
                            NULLIF(LOCATE(', Battery', details_raw), 0),
                            LENGTH(details_raw) + 1) - (LOCATE(', display', details_raw) + LENGTH(', display '))))
        ELSE NULL
    END,
    camera = CASE
        WHEN
            LOCATE(', Camera', details_raw) > 0
        THEN
            TRIM(SUBSTRING(details_raw,
                    LOCATE(', Camera', details_raw) + LENGTH(', Camera '),
                    COALESCE(NULLIF(LOCATE(', Battery', details_raw), 0),
                            LENGTH(details_raw) + 1) - (LOCATE(', Camera', details_raw) + LENGTH(', Camera '))))
        ELSE NULL
    END,
    battery = CASE
        WHEN
            LOCATE(', Battery', details_raw) > 0
        THEN
            TRIM(SUBSTRING(details_raw,
                    LOCATE(', Battery', details_raw) + LENGTH(', Battery ')))
        ELSE NULL
    END;

-- ------------------------------------------------------------------------------------
-- 3.4: Performance (Cores, Clock Speed, Chipset, RAM)
-- This section further parses the 'performance' column created in the previous step.
-- It extracts and cleans the individual performance metrics into their respective columns.
-- ------------------------------------------------------------------------------------

-- Purpose: Extract core count (text), clock speed, chipset name, and RAM size in a single pass.
-- For clock speed and RAM, it uses CASE statements to handle and standardize different units (MHz vs GHz, MB vs GB),
-- converting everything to a common base (GHz and GB).
-- The chipset regex is designed to capture the full name by identifying a known manufacturer and extracting
-- text until it encounters the RAM specification or the end of the string.
UPDATE data_cleaning
SET
	cores =
		REGEXP_SUBSTR(performance, '[A-Za-z]+(?= ?[Cc]ore)'),
        
	clock_speed_ghz =
		CASE 
			WHEN performance LIKE '%MHz%' 
			THEN ROUND(REGEXP_SUBSTR(performance, '[0-9]+\\.?[0-9]*') / 1000, 2)
			ELSE TRIM(REPLACE(REGEXP_SUBSTR(performance, '[0-9]+(\\.[0-9]+)?\\sGHz'), ' GHz', ''))
		END,
        
	chipset =
		TRIM(REGEXP_SUBSTR(performance,
				'(MediaTek|Helio|Snapdragon|Samsung|Exynos|Apple|Unisoc|Google|Spreadtrum|HiSilicon|Broadcom|Intel|Marvell|ST-Ericsson)(.*?)(?=((1|1.5|2|3|4|6|8|10|12|16)[[:space:]]*GB)|((380|384|576|1|8|16|32|48|64|128|160|256|512|768|4)[[:space:]]*(MB)) RAM|$)')),
	
    ram_in_gb =
		CASE
			WHEN performance REGEXP 'MB'
			THEN TRIM(ROUND(REPLACE(REGEXP_SUBSTR(performance, '(380|384|576|1|8|16|32|48|52|56|64|128|160|256|290|512|768|4)[[:space:]]*(MB) RAM'), ' MB RAM', '') / 1024,2))
			WHEN performance REGEXP 'GB'
			THEN TRIM(REGEXP_REPLACE(REGEXP_SUBSTR(performance, '(1|1.5|2|3|4|6|8|10|12|16)[[:space:]]*(GB) RAM'), ' GB RAM|GB RAM', ''))
			ELSE NULL
		END;

-- Purpose: Convert the textual core descriptions (e.g., 'Octa', 'Quad') into their numeric equivalents.
-- This is done in a separate step for clarity and makes the final 'no_of_cores' column ready for numerical analysis.
UPDATE data_cleaning
SET
	no_of_cores = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(cores, 'Single', 1), 'Dual', 2), 'Quad', 4), 'Hexa', 6), 'Octa', 8), 'Nona', 9), 'Deca', 10);

-- ------------------------------------------------------------------------------------
-- 3.5: Display (Size, Resolution, Type)
-- This section parses the 'display' column to extract and standardize screen size,
-- resolution, pixel dimensions, and display technology. It involves multiple steps
-- to handle cases where resolution is given as a category (e.g., 'FHD+') versus
-- explicit pixel dimensions (e.g., '1080x1920').
-- ------------------------------------------------------------------------------------

-- Step 3.5.1: Initial extraction of display attributes.
-- This query performs the first pass on the 'display' string. It uses regex to extract
-- screen size in both inches and cm. It also extracts the resolution, intelligently handling
-- different formats (pixel-based like '1080x2400' or categorical like 'FHD+').
-- Finally, it extracts the display panel type (e.g., 'AMOLED', 'LCD').

UPDATE data_cleaning
SET
	display_size_in_inches = TRIM(REGEXP_REPLACE(REGEXP_SUBSTR(display, '[0-9][[:space:]]?(\\.[0-9]+[[:space:]]?)?(?=inches)'), '(\\.0 )?', '')),
    
    display_size_in_cm = TRIM(REGEXP_REPLACE(REGEXP_SUBSTR(display, '[0-9]+(\\.[0-9]+)?(?=[[:space:]]?cm)'), '(\\.00)?', '')),
    
    resolution =
		CASE
			WHEN display REGEXP 'px'
			THEN REGEXP_REPLACE(REPLACE(REGEXP_SUBSTR(display, '([0-9]+\\.)?[0-9]+[[:space:]]?(x)[[:space:]]?[0-9]+(?=[[:space:]](px|pixels))'), '.00', ''), '\\s+', '')
			WHEN (display LIKE '%HD%' OR display LIKE '%SD%') AND display NOT LIKE '%+%'
			THEN REGEXP_SUBSTR(display, 'SD|HD|FHD|FULL HD|QHD|UHD')
			WHEN display LIKE '%+%'
			THEN REGEXP_SUBSTR(display, 'HD\\+|FHD\\+|FULL HD\\+|QHD\\+|UHD\\+')
			ELSE NULL
		END,
        
	display_type =
		TRIM(REGEXP_SUBSTR(display,
			'(?<=, )([A-Za-z]+\\-)?[A-Za-z]+(\\s[A-Za-z]+\\-[A-Za-z]+)?(\\s[A-Za-z]+)?(\\s[A-Za-z]+)?(\\s[A-Za-z]+)?(\\s[A-Za-z]+)?(\\s[0-9])?(\\s[0-9]x)?((?=(60|90|120|144|165|240))|$)'));

-- Step 3.5.2: Standardize resolution categories to pixel dimensions in a temporary column.
-- This creates a helper column `resolution_in_px`. It uses a CASE statement to map common
-- resolution names (like 'HD', 'FHD') to their standard pixel string equivalents (e.g., '720x1280').
-- If the resolution was already in pixel format, it's carried over unchanged.
UPDATE data_cleaning
SET
	resolution_in_px =
		CASE
			WHEN resolution = 'SD' THEN '480x640'
			WHEN resolution = 'HD' THEN '720x1280'
			WHEN resolution = 'HD+' THEN '720x1520'
			WHEN resolution = 'FHD' OR resolution = 'FULL HD' THEN '1080x1920'
			WHEN resolution = 'FHD+' THEN '1080x2220'
			WHEN resolution = 'QHD' THEN '1440x2560'
			WHEN resolution = 'QHD+' THEN '1440x3120'
			WHEN resolution = 'UHD' THEN '2160x3840'
			ELSE resolution
		END;

-- Step 3.5.3: Split the standardized pixel string into separate width and height columns.
-- Using the `resolution_in_px` helper column, this query parses the string on the 'x'
-- delimiter to populate the final numeric `px_width` and `px_height` columns.
UPDATE data_cleaning
SET
	px_width = SUBSTRING_INDEX(resolution_in_px, 'x', 1),
    px_height = SUBSTRING_INDEX(resolution_in_px, 'x', -1);

-- Step 3.5.4: Re-categorize the `resolution` column based on pixel height for consistency.
-- This is a crucial standardization step. It overwrites the `resolution` column, using the numeric
-- `px_height` to assign a definitive category (e.g., any height between 1950 and 2250 becomes 'FHD+').
-- This ensures that all rows have a consistent resolution category, regardless of how it was originally formatted.
UPDATE data_cleaning
SET
	resolution =
		CASE
			WHEN px_height <= 3150 AND px_height > 2500 THEN 'QHD+'
			WHEN px_height <= 2500 AND px_height > 2250 THEN 'QHD'
			WHEN px_height <= 2250 AND px_height > 1950 THEN 'FHD+'
			WHEN px_height <= 1950 AND px_height > 1650 THEN 'FHD'
			WHEN px_height <= 1650 AND px_height > 1300 THEN 'HD+'
			WHEN px_height <= 1300 AND px_height > 700 THEN 'HD'
			WHEN px_height <= 700 AND px_height > 450 THEN 'SD'
			WHEN px_height <= 450 THEN 'SUB SD'
			ELSE NULL
		END
WHERE resolution REGEXP '[0-9]+x[0-9]+';

-- Step 3.5.5: Final cleanup of resolution names.
-- Standardizes variations like 'FULL HD' to the more common 'FHD'.
UPDATE data_cleaning
SET
	resolution = REPLACE(resolution, 'FULL HD', 'FHD');


-- ------------------------------------------------------------------------------------
-- 3.6: Camera (Rear, Front, Megapixels, Flash)
-- This section parses the 'camera' column to separate the rear and front camera
-- descriptions, extract the flash type, and then pull out the numeric megapixel
-- values for the primary and front cameras.
-- ------------------------------------------------------------------------------------

-- Step 3.6.1: Split the main camera string into separate descriptive columns.
-- This query populates the text-based columns for `rear_camera`, `front_camera`, and `flash`.
-- It uses a combination of SUBSTRING_INDEX and REGEXP_SUBSTR to isolate each component.
-- The logic for `flash` is particularly complex, using nested functions to handle
-- various formats and placements of the flash description within the camera string.
UPDATE data_cleaning
SET
	rear_camera =
		CASE
			WHEN camera REGEXP '^[^0-9]' THEN NULL
			ELSE TRIM(SUBSTRING_INDEX(camera, 'Primary Camera', 1)) 
		END,
    front_camera = TRIM(REGEXP_SUBSTR(camera, '(([0-9]+\\.)?[0-9]+\\s?[A-Za-z]+(\\s\\+\\s)?([0-9]+\\s[A-Za-z]+\\s[A-Za-z]+)?(?= Front))')),
    flash =
		CASE
			WHEN camera LIKE '%,%' THEN TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(SUBSTRING_INDEX(camera, 'Flash,', -1), 'Flash', 1), 'Primary Camera s', -1))
			ELSE TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(REGEXP_REPLACE(SUBSTRING_INDEX(SUBSTRING_INDEX(SUBSTRING_INDEX(camera, 'Flash', 1), 'Primary Camera s', -1), 'Primary Camera', -1), '[0-9]|\\.', ''), 'MP', 1), 'Front', 1))
		END;

-- Step 3.6.2: Clean up missing flash data.
-- This sets the flash column to NULL if the extraction resulted in an empty string or 'No',
-- ensuring consistent representation of missing data.
UPDATE data_cleaning
SET
	 flash = NULL
WHERE flash = '' OR flash = 'No';

-- Step 3.6.3: Extract numeric megapixel values from the camera description strings.
-- This query parses the `rear_camera` and `front_camera` text columns to get the primary
-- megapixel value (the first number found). This populates the final numeric columns
-- `primary_cam_mp` and `front_cam_mp` for quantitative analysis.
UPDATE data_cleaning
SET
	primary_cam_mp = REGEXP_SUBSTR(rear_camera, '^[0-9]+(\\.[0-9]+)?'),
    front_cam_mp = REGEXP_SUBSTR(front_camera, '^[0-9]+(\\.[0-9]+)?');

-- ------------------------------------------------------------------------------------
-- 3.7: Battery (Capacity, CHARging, Removability)
-- This section parses the 'battery' column to extract the battery capacity in mAh,
-- the CHARging port type, USB version, fast-CHARging technology, and whether
-- the battery is removable.
-- ------------------------------------------------------------------------------------

-- Purpose: Extract and clean all battery-related specifications in a single query.
-- It uses specific regex patterns to find and isolate each attribute from the string.
-- The `Removable_Battery` column is populated using a CASE statement that checks for the
-- presence of "Removable" or "Non-Removable" keywords to accurately assign 'Yes' or 'No'.
UPDATE data_cleaning
SET
	battery_mah = CAST(TRIM(NULLIF(REGEXP_SUBSTR(battery, '[0-9]+(?=(\\s)?mAh)'), '')) AS DOUBLE),
    charging_port = TRIM(REGEXP_SUBSTR(battery, 'Micro-USB|microUSB|miniUSB|Proprietary|Type-C|Lightning')),
    usb_version = TRIM(REGEXP_SUBSTR(battery, '[0-9]\\.[0-9](?=USB)')),
    charging_type = TRIM(REPLACE(REGEXP_SUBSTR(battery, '(([0-9]+)?[A-Za-z]+\\s)?[A-Za-z]+(?= CHARging)'), 'mAh', '')),
    removable_battery =
		CASE
			WHEN battery LIKE '%Removable%' AND Battery NOT LIKE '%Non-Removable%'
			THEN 'Yes'
			WHEN battery LIKE '%Non-Removable%'
			THEN 'No'
			ELSE NULL
		END;

-- ------------------------------------------------------------------------------------
-- 3.8: Other Features (Storage, SIM, Connectivity, Protection)
-- This section parses the 'features_raw' column, which contains a mix of different
-- specifications. The queries extract storage details, SIM configuration, feature flags
-- like Wi-Fi calling and fingerprint sensors, and device protection ratings.
-- ------------------------------------------------------------------------------------

-- Step 3.8.1: Parse the 'features_raw' string to extract multiple features.
-- This query populates several columns in a single pass. The 'storage_in_gb' logic is
-- complex, using a CASE statement to handle various units (KB, MB, GB, TB) and
-- convert them all to a standardized GB value. It also creates a temporary `expandable_storage`
-- text column for later processing, and extracts SIM info, feature flags, and IP ratings.
UPDATE data_cleaning
SET
	storage_in_gb =
		CASE
			WHEN features_raw LIKE '%KB%'
			THEN 0
			WHEN features_raw LIKE '%MB%'
			THEN TRIM(ROUND(REGEXP_SUBSTR(features_raw, '([0-9]+\\.)?[0-9]+\\s?(?=MB)') /1024, 2))
			WHEN features_raw LIKE '% GB%'
			THEN TRIM(REGEXP_SUBSTR(features_raw, '([0-9]+\\.)?[0-9]+(?= GB)'))
			WHEN features_raw LIKE '%TB%' AND CAST(TRIM(REGEXP_SUBSTR(features_raw, '([0-9]+\\.)?[0-9]+(?=(\\s?)TB)')) AS UNSIGNED) <= 2
			THEN TRIM(REGEXP_SUBSTR(features_raw, '([0-9]+\\.)?[0-9]+(?=(\\s?)TB)') * 1024)
            WHEN features_raw LIKE '%TB%' AND CAST(TRIM(REGEXP_SUBSTR(features_raw, '([0-9]+\\.)?[0-9]+(?=(\\s?)TB)')) AS UNSIGNED) > 2
			THEN TRIM(REGEXP_SUBSTR(features_raw, '([0-9]+\\.)?[0-9]+(?=(\\s?)TB)'))
			ELSE NULL
		END,
        
	expandable_storage = TRIM(REPLACE(REGEXP_SUBSTR(features_raw, '([0-9]+\\s?)?[A-Za-z]+(?= Expandable)'), 'Non', 0)),
    
    sim =
        CASE
			WHEN features_raw LIKE '%Dual SIM:%'
			THEN TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(REGEXP_SUBSTR(features_raw, 'Dual SIM:\\s[A-Za-z]+(\\s\\+\\s[A-Za-z]+)?'), 'Not', 1), 'Supported', 1))
			WHEN features_raw LIKE '%Dual SIM%' AND features_raw NOT LIKE '%:%'
			THEN 'Dual SIM'
			WHEN features_raw LIKE '%Triple SIM%'
			THEN 'Triple SIM'
			ELSE NULL
		END,
        
	wifi_calling =
		CASE
			WHEN features_raw LIKE '%Wi-Fi Calling%'
			THEN 'Yes'
			ELSE 'No'
		END,
        
	fingerprint_sensor =
        CASE
			WHEN features_raw LIKE '%No Fingerprint%'
			THEN 'No'
			WHEN features_raw LIKE '%Fingerprint%' AND features_raw NOT LIKE '%No Fingerprint%'
			THEN 'Yes'
			ELSE NULL
		END,
        
	protection = TRIM(REGEXP_REPLACE(REPLACE(REGEXP_SUBSTR(features_raw, 'IP\\s?(X)?[0-9]+(X)?(\\,\\s?IP(X)?[0-9]+)?(\\,\\s?IP[0-9]+(X)?)?'), ',', ', '), '\\s+', ' '));

-- Step 3.8.2: Correct potential data entry errors in the temporary `expandable_storage` column.
-- This handles an edge case where a large value in TB was likely intended to be GB, standardizing the unit text before final numeric conversion.
UPDATE data_cleaning
SET
	expandable_storage =
		CASE
			WHEN expandable_storage LIKE '%TB%' AND CAST(REGEXP_SUBSTR(expandable_storage, '[0-9]+') AS UNSIGNED) > 2
			THEN REPLACE(expandable_storage, 'TB', 'GB')
			ELSE expandable_storage
		END;

-- Step 3.8.3: Convert the cleaned `expandable_storage` text into the final numeric GB column.
-- This query reads the temporary text column, checks the unit (TB or GB), performs the necessary
-- mathematical conversion (multiplying TB by 1024), and populates the final `expandable_storage_in_gb` column.
UPDATE data_cleaning
SET
	expandable_storage_in_gb = 
		CASE
			WHEN expandable_storage LIKE '%TB'
            THEN REGEXP_SUBSTR(expandable_storage, '[0-9]+') * 1024
            WHEN expandable_storage LIKE '%GB'
            THEN REGEXP_SUBSTR(expandable_storage, '[0-9]+')
            WHEN expandable_storage LIKE '%MB'
            THEN REGEXP_SUBSTR(expandable_storage, '[0-9]+') / 1024
            WHEN expandable_storage = 0
            THEN 0
            ELSE NULL
		END;

-- ================================================================================================
-- SECTION 4: FINAL CLEANUP
-- ================================================================================================

-- Purpose: Drop the raw, unprocessed columns as they are now redundant.
-- This keeps the final working table clean and focused.
ALTER TABLE data_cleaning
    DROP COLUMN spec_score_raw,
    DROP COLUMN os_raw,
    DROP COLUMN price_raw,
    DROP COLUMN details_raw,
    DROP COLUMN features_raw,
    DROP COLUMN performance,
    DROP COLUMN cores,
    DROP COLUMN display,
    DROP COLUMN camera,
    DROP COLUMN battery,
    DROP COLUMN resolution_in_px,
    DROP COLUMN expandable_storage;

-- ================================================================================================
-- SECTION 5: NULL HANDLING
-- ================================================================================================

/*
RECOMMENDATION FOR NULL HANDLING:

For this dataset, it's best to adopt a hybrid approach:
1.  Numeric Columns (Keep NULL):
	For columns like `price`, `ram_in_gb`, `px_width`, `battery_mah`, etc., `NULL` is the correct choice.
	`NULL` mathematically represents a missing or unknown value.
    Replacing it with 0 would incorrectly skew calculations like averages.
	For example, an average price would be artificially lowered if missing prices were treated as 0.

2.  Text/Categorical Columns (Replace with 'No Data'):
	For columns like `chipset`, `display_type`, `protection`, and `CHARging_type`,
    replacing `NULL` with a descriptive string like 'No Data' or 'Not Specified' can be beneficial.
    This makes the data more user-friendly in BI tools (like Tableau or Power BI)
    where filters will explicitly show a 'No Data' category instead of a potentially confusing '(Null)' option.
    It also prevents accidental exclusion of rows in queries that use `column = 'some_value'`.

This approach maintains analytical integrity for numeric fields while improving usability for categorical fields.
*/

-- Purpose: Apply the 'No Data' string to text-based columns where values are NULL.
-- This makes the final dataset friendlier for reporting and visualization tools.
UPDATE data_cleaning
SET
    operating_system = IFNULL(operating_system, 'No Data'),
    chipset = IFNULL(chipset, 'No Data'),
    resolution = IFNULL(resolution, 'No Data'),
    display_type = IFNULL(display_type, 'No Data'),
    rear_camera = IFNULL(rear_camera, 'No Data'),
    front_camera = IFNULL(front_camera, 'No Data'),
    flash = IFNULL(flash, 'No Data'),
    charging_port = IFNULL(charging_port, 'No Data'),
    charging_type = IFNULL(charging_type, 'No Data'),
    removable_battery = IFNULL(removable_battery, 'No Data'),
    sim = IFNULL(sim, 'No Data'),
    wifi_calling = IFNULL(wifi_calling, 'No Data'),
    fingerprint_sensor = IFNULL(fingerprint_sensor, 'No Data'),
    protection = IFNULL(protection, 'No Data');

-- ================================================================================================
-- SECTION 6: CREATE FINAL CLEANED TABLE
-- ================================================================================================

-- Purpose: Create the final, polished table 'cleaned_data'.
-- This uses the DROP IF EXISTS / CREATE AS SELECT pattern for idempotency.
-- The SELECT statement explicitly lists and casts columns to ensure the final schema is
-- exactly as intended and does not carry over any artifacts from the 'data_cleaning' table.
DROP TABLE IF EXISTS cleaned_data;
CREATE TABLE cleaned_data AS
SELECT
    CAST(mobile AS CHAR(255)) AS mobile,
	price,
    spec_score,
    CAST(operating_system AS CHAR(100)) AS operating_system,
    CAST(os_version AS CHAR(10)) AS os_version,
    no_of_cores,
    clock_speed_ghz,
    CAST(chipset AS CHAR(100)) AS chipset,
    ram_in_gb,
    display_size_in_inches,
    display_size_in_cm,
    CAST(resolution AS CHAR(50)) AS resolution,
    px_width,
    px_height,
    CAST(display_type AS CHAR(50)) AS display_type,
    CAST(rear_camera AS CHAR(255)) AS rear_camera,
    primary_cam_mp,
    CAST(front_camera AS CHAR(255)) AS front_camera,
    front_cam_mp,
    CAST(flash AS CHAR(50)) AS flash,
    battery_mah,
    CAST(charging_port AS CHAR(50)) AS charging_port,
    usb_version,
    CAST(charging_type AS CHAR(50)) AS charging_type,
    removable_battery,
    storage_in_gb,
    expandable_storage_in_gb,
    CAST(sim AS CHAR(100)) AS sim,
    wifi_calling,
    fingerprint_sensor,
    CAST(protection AS CHAR(30)) AS protection
FROM data_cleaning;

-- Add a primary key for better performance and data integrity.
ALTER TABLE cleaned_data ADD COLUMN id INT AUTO_INCREMENT PRIMARY KEY FIRST;

-- ================================================================================================
-- SECTION 8: FINAL VERIFICATION
-- ================================================================================================

-- Purpose: Display a sample of the final cleaned data to verify the script's output.
SELECT * FROM cleaned_data LIMIT 100;

-- ================================================================================================
-- SECTION 9: DATA QUALITY SUMMARY
-- ================================================================================================

-- Purpose: Provide a quantitative summary of the final cleaned data.
-- This query calculates the total number of records and counts the number of missing values
-- for key columns. It's a powerful way to assess the completeness of the dataset after cleaning
-- and to understand which features have the most gaps.

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) AS missing_price,
    ROUND(SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS missing_price_pct,
    SUM(CASE WHEN ram_in_gb IS NULL THEN 1 ELSE 0 END) AS missing_ram,
    ROUND(SUM(CASE WHEN ram_in_gb IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS missing_ram_pct,
	SUM(CASE WHEN storage_in_gb IS NULL THEN 1 ELSE 0 END) AS missing_storage,
    ROUND(SUM(CASE WHEN storage_in_gb IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS missing_storage_pct,
    SUM(CASE WHEN chipset = 'No Data' THEN 1 ELSE 0 END) AS missing_chipset,
    ROUND(SUM(CASE WHEN chipset = 'No Data' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS missing_chipset_pct,
    SUM(CASE WHEN battery_mah IS NULL THEN 1 ELSE 0 END) AS missing_battery_mah,
    ROUND(SUM(CASE WHEN battery_mah IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS missing_battery_mah_pct
FROM
    cleaned_data;